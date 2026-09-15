#!/bin/bash
# ============================================================================
#  Timer Deck — 打包成 macOS App
#  用 Xcode Command Line Tools 的 swiftc 编译，不依赖 Xcode.app
#
#  注意：这个脚本不做任何删除动作 —— 直接就地覆盖更新，
#        所以不会触发系统的档案保护。
#
#  编译输出放在隐藏目录 .build/ —— Spotlight 不会索引隐藏目录，
#  所以这份「开发用」的 app 不会出现在启动器 / Spotlight 结果里，
#  只有 ~/Applications 那份会显示。（.metadata_never_index 是双保险）
# ============================================================================

set -e
cd "$(dirname "$0")"

APP_NAME="Timer Deck"
EXEC_NAME="TimerDeck"
BUNDLE_ID="com.bassoonowlpie.timerdeck"
VERSION="1.4.0"
BUILD_DIR=".build"
APP="$BUILD_DIR/$APP_NAME.app"
# 项目自身目录（音效等资源就在本项目内，clone 后可直接编译）
SRC_EXT="$(cd "$(dirname "$0")" && pwd)"

echo "=== 1/5 准备目录 ==="
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources/sounds"
# 告诉 Spotlight 不要索引这个目录（避免出现第二个 Timer Deck 图示）
touch "$BUILD_DIR/.metadata_never_index"

echo "=== 2/5 编译 Swift ==="
swiftc -O \
  -target arm64-apple-macos13.0 \
  -swift-version 5 \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework UserNotifications \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/$EXEC_NAME"

echo "=== 3/5 放入音效 ==="
cp "$SRC_EXT/sounds/"*.wav "$APP/Contents/Resources/sounds/"

echo "=== 4/5 产生 App 图示 ==="
# 用 AppIcon/AppIcon.iconset（由 make_app_icon.py 产生，含 1024 母档）
# 之前是用 extension 那张 128px 图放大，大尺寸下会糊。
ICONSET="AppIcon/AppIcon.iconset"
if [ -d "$ICONSET" ]; then
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" \
    && echo "  ✓ AppIcon.icns（1024 母档 → 全套尺寸）" \
    || echo "  (图示转换失败，沿用旧的)"
else
  echo "  ⚠️ 缺少 $ICONSET —— 先执行：python3 make_app_icon.py"
fi

echo "=== 5/5 写入 Info.plist 并签名 ==="
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$EXEC_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Timer Deck</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (签名略过，仍可执行)"

echo ""
echo "✅ 完成：$APP"
du -sh "$APP" | awk '{print "   体积: "$1}'
