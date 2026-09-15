# Timer Deck

macOS 選單列上的多功能計時器 —— 唔使開視窗，抬頭就知仲有幾耐。

<p align="center">
  <img src="screenshots/19-icon-1024.png" width="140" alt="Timer Deck">
</p>

## 功能

- **選單列常駐** —— 收埋喺 Menu Bar，唔佔 Dock，唔阻你做嘢
- **多個計時器同時跑** —— 每個獨立倒數，各自設定時長同提示音
- **選單列直接顯示剩餘時間** —— 只有一個計時器進行中時，Menu Bar 位會換成倒數數字（`12:34`）
- **預設計時器一鍵開始** —— 常用時長存起上嚟，新開嘅計時器自動開始倒數
- **右鍵選單列圖示** —— 即刻開啟儀表板 / 設定 / 退出
- **提示音可選** —— 內建 4 種音效（ping / chime / bell / alarm）
- **深色 / 淺色模式**，中英雙語介面
- **完全離線** —— 唔連網，所有資料留喺你自己部電腦

## 畫面

| 主面板 | 新增計時器 |
| :---: | :---: |
| ![主面板](screenshots/01-panel-list.png) | ![新增計時器](screenshots/02-panel-form.png) |

| 儀表板 | 設定 |
| :---: | :---: |
| ![儀表板](screenshots/03-dashboard.png) | ![設定](screenshots/04-settings.png) |

## 下載安裝

1. 去 **[Releases](https://github.com/bassoonowlpie/timer-deck-mac/releases/latest)** 下載最新嘅 `TimerDeck-x.x.x-macOS.zip`
2. 解壓，將 `Timer Deck.app` 拖入 `/Applications`（或 `~/Applications`）
3. 第一次開 —— **macOS 會攔你**，睇下面 👇

### ⚠️ 第一次開啟：macOS 會話「無法打開」

呢個 app 冇 Apple 付費開發者簽名，所以 macOS 會彈：

> 「Apple 無法檢查『Timer Deck』是否包含惡意軟件」
> 或者：「Timer Deck 已損壞，無法打開」

**三個解法，任揀一個：**

**方法 A —— 系統設定（最直觀）**

`系統設定` → `私隱與保安` → 捲到下面「保安」一欄 → 見到 Timer Deck 嘅提示 → 撳 `仍要開啟` → 再確認一次。

**方法 B —— 右鍵開啟（最快）**

喺 Finder 對 `Timer Deck.app` 撳**右鍵** → 揀 `打開` → 彈窗再撳一次 `打開`。
之後就可以正常雙擊開啟。

**方法 C —— 終端機（最乾脆）**

```bash
xattr -cr "/Applications/Timer Deck.app"
```

> **點解會咁？** macOS 對所有從網絡下載嘅 app 都會查「公證（notarization）」，而公證要 Apple 每年 US$99 嘅開發者帳號。呢個小工具係免費分享，所以用咗本機簽名。上面三個方法都只係一次性。

## 系統要求

- macOS 13 Ventura 或以上
- **Apple Silicon（M1 / M2 / M3 / M4）**

> 目前只編譯咗 arm64。Intel Mac 暫時未支援，可以自己由原始碼編譯（見下）。

## 由原始碼編譯

只需要 Xcode Command Line Tools，唔使裝完整 Xcode：

```bash
xcode-select --install        # 如果未裝過
git clone https://github.com/bassoonowlpie/timer-deck-mac.git
cd timer-deck-mac
./build.sh
open ".build/Timer Deck.app"
```

編譯產物放喺 `.build/`（隱藏目錄）—— 咁樣 Spotlight 就唔會索引到第二個 `Timer Deck.app`，避免啟動器出現重複圖示。

## 資料存放位置

| 內容 | 路徑 |
| --- | --- |
| 計時器資料 | `~/Library/Application Support/TimerDeck/deck.json` |
| 偏好設定 | `~/Library/Preferences/com.bassoonowlpie.timerdeck.plist` |

想備份或者搬去新機，抄呢兩個檔就得。卸載就係刪走 app + 呢兩個檔。

## 授權

[MIT](LICENSE) —— 隨便用、改、再分享。

---

## English

**Timer Deck** is a lightweight menu-bar timer for macOS 13+ (Apple Silicon). It keeps running timers one click away, shows the remaining time right in the menu bar when a single timer is active, and stores everything locally — no network access at all.

**Install:** download the latest `TimerDeck-x.x.x-macOS.zip` from [Releases](https://github.com/bassoonowlpie/timer-deck-mac/releases/latest), unzip, drag `Timer Deck.app` into `/Applications`.

**First launch is blocked by Gatekeeper**, because the app is ad-hoc signed instead of notarized (notarization requires a paid Apple Developer account). Fix it with any of:

- **System Settings** → Privacy & Security → scroll down → *Open Anyway*
- **Right-click** the app in Finder → *Open* → *Open*
- **Terminal:** `xattr -cr "/Applications/Timer Deck.app"`

**Build from source:** `./build.sh` — requires only Xcode Command Line Tools.

Licensed under the [MIT License](LICENSE).
