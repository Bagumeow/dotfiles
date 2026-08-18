#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# orca/apply-settings.sh — áp orca/settings.json vào Orca đang cài trên máy.
#
#   ./orca/apply-settings.sh                # tắt Orca -> merge -> mở lại
#   ./orca/apply-settings.sh --merge-only    # chỉ merge, đòi Orca đã tắt sẵn
#   ./orca/apply-settings.sh --if-possible   # merge nếu được, Orca đang chạy thì bỏ qua
#                                            # (install.sh / watch.sh gọi mode này)
#
# Vì sao cần script riêng: settings của Orca không có file config riêng mà nằm ở
# .settings TRONG state file profiles/<activeProfileId>/orca-data.json (chung với
# projects, worktree, session). App giữ state trong memory và ghi đè file liên tục
# -> chỉ merge được lúc app đã tắt. Tắt bằng `quit app` (KHÔNG kill) để Orca kịp
# flush state cuối, rồi mới merge đè lên.
#
# KHÔNG chạy mode mặc định từ terminal BÊN TRONG Orca: tắt app là pty chết theo,
# script tự sát giữa đường. Mở Alacritty (alias `ala`) rồi chạy.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/settings.json"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

MODE="restart"
case "${1-}" in
  "")            MODE="restart" ;;
  --merge-only)  MODE="merge" ;;
  --if-possible) MODE="soft" ;;
  -h|--help)     sed -n '2,19p' "${BASH_SOURCE[0]}"; exit 0 ;;
  *)             die "tham số lạ: $1 (dùng --merge-only | --if-possible | --help)" ;;
esac

[ "$(uname -s)" = "Darwin" ] || die "script này chỉ dành cho macOS."
command -v jq >/dev/null 2>&1 || die "thiếu jq — brew install jq"
[ -f "$SRC" ] || die "không thấy $SRC"
jq -e . "$SRC" >/dev/null 2>&1 || die "$SRC không phải JSON hợp lệ"

SUPPORT="$HOME/Library/Application Support/orca"
PROFILE="$(jq -r '.activeProfileId // "local-default"' \
  "$SUPPORT/orca-profile-index.json" 2>/dev/null || echo local-default)"
DATA="$SUPPORT/profiles/$PROFILE/orca-data.json"

orca_running() { pgrep -x Orca >/dev/null 2>&1; }

# Chạy mode mặc định từ trong Orca thì tắt app xong là script chết -> chặn sớm.
if [ "$MODE" = "restart" ] && { [ "${TERM_PROGRAM-}" = "Orca" ] || [ -n "${ORCA_PANE_KEY-}" ]; }; then
  die "đang chạy trong terminal của Orca — tắt app là script chết theo.
    Mở Alacritty (alias \`ala\`) rồi chạy lại, hoặc tự Cmd-Q Orca rồi dùng --merge-only."
fi

if [ ! -f "$DATA" ]; then
  [ "$MODE" = "soft" ] && { warn "chưa có $DATA — mở Orca một lần trước."; exit 0; }
  die "chưa có $DATA — mở Orca một lần rồi chạy lại."
fi

RELAUNCH=0
if orca_running; then
  case "$MODE" in
    merge)
      die "Orca đang chạy — Cmd-Q trước rồi chạy lại (app ghi đè orca-data.json từ memory)."
      ;;
    soft)
      warn "Orca đang chạy — BỎ QUA merge settings (app sẽ ghi đè lại từ memory)."
      warn "Tắt Orca rồi chạy: ./orca/apply-settings.sh"
      exit 0
      ;;
    restart)
      log "Tắt Orca (quit êm để app kịp flush state cuối)..."
      osascript -e 'quit app "Orca"' >/dev/null 2>&1 || warn "osascript quit lỗi"
      for _ in $(seq 1 30); do
        orca_running || break
        sleep 1
      done
      if orca_running; then
        die "Orca vẫn chưa tắt sau 30s — tắt tay rồi chạy lại với --merge-only."
      fi
      sleep 1   # chờ app ghi xong state cuối trước khi merge đè lên
      RELAUNCH=1
      ;;
  esac
fi

log "Merge settings vào profile $PROFILE..."
cp "$DATA" "$DATA.bak.$(date +%Y%m%d%H%M%S)"
tmp="$(mktemp)"
# `*` của jq merge đệ quy -> ~180 setting khác và toàn bộ state giữ nguyên,
# chỉ mấy key trong orca/settings.json bị ghi đè.
if jq -s '.[0] * {settings: .[1]}' "$DATA" "$SRC" > "$tmp"; then
  mv "$tmp" "$DATA"
  jq -r 'to_entries[] | "    \(.key) = \(.value)"' "$SRC"
else
  rm -f "$tmp"
  die "jq merge lỗi — giữ nguyên orca-data.json"
fi

if [ "$RELAUNCH" = 1 ]; then
  log "Mở lại Orca..."
  open -a Orca
else
  warn "Mở Orca để thấy thay đổi (Window Blur chỉ áp khi app khởi động lại)."
fi
