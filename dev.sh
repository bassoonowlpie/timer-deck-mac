#!/bin/bash
# ============================================================================
#  Timer Deck — 开发辅助
#
#  跑自测 / 渲染预览 / 右键菜单探针时，一律把存档写到临时目录，
#  绝不会碰到 ~/Library/Application Support/TimerDeck 里使用者真正的资料。
#
#  用法：
#    ./dev.sh selftest
#    ./dev.sh render [输出目录]
#    ./dev.sh probe
# ============================================================================

set -e
cd "$(dirname "$0")"

APP=".build/Timer Deck.app/Contents/MacOS/TimerDeck"
SANDBOX="$(mktemp -d)/TimerDeck"
mkdir -p "$SANDBOX"
export TIMERDECK_DATA_DIR="$SANDBOX"

case "${1:-selftest}" in
  selftest)
    "$APP" --selftest
    ;;
  render)
    "$APP" --render-ui --out="${2:-preview}"
    ;;
  probe)
    "$APP" --probe-menu || true
    echo "--- probe.txt ---"
    cat "$SANDBOX/probe.txt" 2>/dev/null || echo "(没有产出)"
    ;;
  *)
    echo "用法: ./dev.sh [selftest|render|probe]"
    exit 1
    ;;
esac
