#!/usr/bin/env python3
# ============================================================================
#  Timer Deck — App 图示产生器
#
#  为什么要这样画：
#  macOS 对 app 图示有固定网格 —— 圆角方块只占画布 **824 / 1024**（80.5%），
#  剩下的是留给阴影的边距。若图示塞满 100% 画布，macOS 会当它是「旧式图示」，
#  自动缩小并垫一块浅灰圆角底板（用户看到的就是「蓝色方块浮在灰色上面」）。
#
#  所以：1024 画布 → 824 圆角方块（超椭圆 n≈4.9，视觉圆角 ≈22.5%）
#        + 向下 16px 高斯模糊阴影。
# ============================================================================
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

CANVAS = 1024
SQUIRCLE = 824                 # 圆角方块边长
SQUIRCLE_R = SQUIRCLE / 2.0    # 412
CX = CY = CANVAS / 2.0
SHADOW_DY = 22
SHADOW_BLUR = 40
SHADOW_ALPHA = 0.32

# 品牌蓝（跟 UI 的 accent #3D7BFF 同一家族）
GRAD_TOP = (108, 160, 255)
GRAD_BOTTOM = (40, 88, 224)

SS = 4                          # 超采样倍数


def squircle_points(cx, cy, half, n=4.9, steps=2880):
    """超椭圆（squircle）外形点列；n≈4.9 对应视觉圆角 ≈22.5%。"""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        x = half * math.copysign(abs(ct) ** (2.0 / n), ct)
        y = half * math.copysign(abs(st) ** (2.0 / n), st)
        pts.append((cx + x, cy + y))
    return pts


def linear_gradient(size, c0, c1, angle_deg=135, lowres=192):
    """斜向线性渐变（左上 c0 → 右下 c1）。

    先在低分辨率算好再放大 —— 渐变本身平滑，放大不会失真，
    但可以把 4096² 的 Python 逐像素循环降到 192²。
    """
    w = h = lowres
    base = Image.new("RGB", (w, h))
    px = base.load()
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    span = abs(dx) * w + abs(dy) * h
    for y in range(h):
        for x in range(w):
            t = ((x - w / 2) * dx + (y - h / 2) * dy) / span + 0.5
            t = min(1.0, max(0.0, t))
            px[x, y] = (
                round(c0[0] + (c1[0] - c0[0]) * t),
                round(c0[1] + (c1[1] - c0[1]) * t),
                round(c0[2] + (c1[2] - c0[2]) * t),
            )
    return base.resize((size, size), Image.BICUBIC)


def rounded_bar(d, cx, cy, w, h, color):
    """胶囊形横条（顶部按把）。"""
    r = h / 2.0
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=r, fill=color)


def thick_line(d, p0, p1, width, color):
    d.line([p0, p1], fill=color, width=int(round(width)))
    # 圆头
    for p in (p0, p1):
        d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=color)


def arc_points(cx, cy, r, start_deg, end_deg, steps=720):
    """从 12 点方向顺时针的圆弧点列。"""
    pts = []
    for i in range(steps + 1):
        deg = start_deg + (end_deg - start_deg) * i / steps
        a = math.radians(deg - 90)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def ring_mask(S, cx, cy, r_out, r_in, start_deg=None, end_deg=None, caps=True):
    """干净的圆环遮罩。

    用「大圆减中圆」做环，而不是画粗折线 —— 粗折线在接点处会出现
    一条条虚线状的接缝纹（实测在浅色底轨上非常明显）。
    """
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    box = [cx - r_out, cy - r_out, cx + r_out, cy + r_out]

    if start_deg is None:
        d.ellipse(box, fill=255)
    else:
        # PIL 的角度以 3 点方向为 0°、顺时针为正 → 减去 90 换成「从 12 点起算」
        d.pieslice(box, start_deg - 90, end_deg - 90, fill=255)
        if caps:
            rr = (r_out - r_in) / 2.0
            r_mid = (r_out + r_in) / 2.0
            for deg in (start_deg, end_deg):
                a = math.radians(deg - 90)
                mx, my = cx + math.cos(a) * r_mid, cy + math.sin(a) * r_mid
                d.ellipse([mx - rr, my - rr, mx + rr, my + rr], fill=255)

    d.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=0)
    return m


def draw_mark(S, s, cx, cy, style, white=(255, 255, 255, 255),
              ring_d=0.72, crown_h=0.066, crown_w=0.300, gap=0.012,
              hand_w_ratio=0.53):
    """产出记号的所有图层：[(遮罩, 颜色), ...]；s = 圆角方块边长。

    几何全部由 ring_d（表圈外径占方块的比例）推算：
      1. 记号总高 = 按把 + 间隙 + 表圈
      2. 上下边距 = (1 - 总高) / 2   → 记号整体在方块内居中
    实测 ring_d 0.68 偏小、0.76 顶到底边，0.72 最平衡。
    """
    layers = []

    ring_r = ring_d / 2.0
    ring_w = ring_d * 0.1486          # 圈粗与外径等比
    inner_r = ring_r - ring_w
    hand_w = ring_w * hand_w_ratio    # 指针约是圈粗的一半

    total_h = crown_h + gap + ring_d
    top_margin = (1.0 - total_h) / 2.0

    top = cy - s / 2.0
    crown_cy = top + (top_margin + crown_h / 2) * s
    ring_cy = top + (top_margin + crown_h + gap + ring_r) * s
    R, r_in = ring_r * s, inner_r * s

    # ---- 顶部按把 ----
    m = Image.new("L", (S, S), 0)
    rounded_bar(ImageDraw.Draw(m), cx, crown_cy, crown_w * s, crown_h * s, 255)
    layers.append((m, white))

    # ---- 表圈 ----
    if style in ("notch", "notch-one"):
        # 12 点方向开一个缺口，按把正好嵌进去
        layers.append((ring_mask(S, cx, ring_cy, R, r_in, 13, 347), white))
    elif style in ("track", "gauge", "gauge-one"):
        layers.append((ring_mask(S, cx, ring_cy, R, r_in), (255, 255, 255, 64)))
        layers.append((ring_mask(S, cx, ring_cy, R, r_in, 0, 259), white))
    else:                                    # full
        layers.append((ring_mask(S, cx, ring_cy, R, r_in), white))

    # ---- 指针（长度按内圈半径推算，指针尖永远不会顶到圈）----
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    hw = hand_w * s
    thick_line(d, (cx, ring_cy), (cx, ring_cy - 0.83 * inner_r * s), hw, 255)
    if style not in ("gauge-one", "notch-one"):
        ang = math.radians(60)               # 4 点方向（往右下，平衡表盘下半部）
        L = 0.65 * inner_r * s
        thick_line(d, (cx, ring_cy),
                   (cx + math.sin(ang) * L, ring_cy + math.cos(ang) * L), hw, 255)
    layers.append((m, white))

    # ---- 中心轴 ----
    m = Image.new("L", (S, S), 0)
    dd = ImageDraw.Draw(m)
    dot = 0.13 * inner_r * s
    dd.ellipse([cx - dot, ring_cy - dot, cx + dot, ring_cy + dot], fill=255)
    layers.append((m, white))

    return layers


def build(size, style="track", with_shadow=True, squircle_grid=True):
    S = size * SS
    k = S / float(CANVAS) if squircle_grid else S / 1024.0

    # --- 圆角方块（渐变底 + 顶部微光）---
    tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if squircle_grid:
        half = SQUIRCLE_R * k
        cx = cy = S / 2.0
    else:
        half = S / 2.0
        cx = cy = S / 2.0

    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(squircle_points(cx, cy, half), fill=255)

    grad = linear_gradient(S, GRAD_TOP, GRAD_BOTTOM).convert("RGBA")
    tile.paste(grad, (0, 0), mask)

    # 顶部柔光（让方块不那么平）
    gloss = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(gloss)
    gd.ellipse([cx - half * 1.05, cy - half * 1.55,
                cx + half * 1.05, cy - half * 0.15], fill=52)
    gloss = gloss.filter(ImageFilter.GaussianBlur(radius=half * 0.22))
    gloss = Image.composite(gloss, Image.new("L", (S, S), 0), mask)
    tile.alpha_composite(Image.merge("RGBA", (
        Image.new("L", (S, S), 255), Image.new("L", (S, S), 255),
        Image.new("L", (S, S), 255), gloss,
    )))

    # --- 符号 ---
    mark = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for mask, color in draw_mark(S, half * 2, cx, cy, style):
        layer = Image.new("RGBA", (S, S), tuple(color) if len(color) == 4 else tuple(color) + (255,))
        mark.alpha_composite(Image.composite(layer, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask))
    tile.alpha_composite(mark)

    if not with_shadow:
        return tile.resize((size, size), Image.LANCZOS)

    # --- 阴影 ---
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    smask = mask.filter(ImageFilter.GaussianBlur(radius=SHADOW_BLUR * k))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, int(255 * SHADOW_ALPHA)))
    canvas.paste(shadow, (0, int(SHADOW_DY * k)), smask)
    canvas.alpha_composite(tile)
    return canvas.resize((size, size), Image.LANCZOS)


ICONSET_NAMES = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def main():
    style = "full"
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        style = args[0]

    root = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(root, "AppIcon")
    iconset = os.path.join(out, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)

    # 同一个尺寸重复出现（例如 32 用在 16@2x 与 32x32）→ 只算一次
    cache: dict[int, Image.Image] = {}
    for size, name in ICONSET_NAMES:
        if size not in cache:
            cache[size] = build(size, style=style)
        cache[size].save(os.path.join(iconset, name))

    master = os.path.join(out, "icon_1024.png")
    cache[1024].save(master)

    print("style   :", style)
    print("iconset :", iconset)
    print("master  :", master)


if __name__ == "__main__":
    main()
