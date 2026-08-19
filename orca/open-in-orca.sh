#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# orca/open-in-orca.sh — mở file trong Orca IDE từ Finder / dòng lệnh.
#
#   ./orca/open-in-orca.sh <file> [file...]
#
# Vì sao cần script này: Orca.app KHÔNG khai báo CFBundleDocumentTypes trong
# Info.plist -> LaunchServices không có gì để bind, nên `open -a Orca <file>`
# chỉ focus app chứ không mở file, và Finder không bao giờ liệt kê Orca trong
# "Open With" (double-click cũng vô hiệu). Đường DUY NHẤT Orca nhận file là CLI
# `orca file open`, và CLI đó chỉ nhận path NẰM TRONG một worktree đã đăng ký:
# nó resolve worktree theo cwd, sai worktree là lỗi `invalid_relative_path`.
#
# Nên script cd vào thư mục chứa file rồi mới gọi `orca file open` -> worktree
# luôn được resolve đúng. Applet Finder (orca/open-in-orca.applescript) gọi
# script này; install.sh compile applet đó thành ~/Applications/Open in Orca.app.
# ---------------------------------------------------------------------------
set -uo pipefail

# Applet Finder chạy không có PATH của shell login -> gọi binary theo path tuyệt
# đối. /usr/local/bin/orca chỉ là symlink tới đây.
ORCA_BIN="/Applications/Orca.app/Contents/Resources/bin/orca"
[ -x "$ORCA_BIN" ] || ORCA_BIN="$(command -v orca 2>/dev/null || true)"

# Báo lỗi ra cả stderr lẫn notification (chạy từ Finder thì không ai thấy stderr).
die() {
  printf '[x] %s\n' "$*" >&2
  osascript -e "display notification \"$1\" with title \"Open in Orca\"" >/dev/null 2>&1
  exit 1
}

[ -n "$ORCA_BIN" ] || die "không thấy Orca CLI — cài Orca trước"
[ $# -gt 0 ] || die "thiếu tham số: cần ít nhất 1 file"

# Runtime chưa sẵn sàng thì `orca file open` fail -> boot app và chờ.
"$ORCA_BIN" status >/dev/null 2>&1 || "$ORCA_BIN" open >/dev/null 2>&1 \
  || die "không khởi động được Orca runtime"

failed=0
for f in "$@"; do
  [ -e "$f" ] || { printf '[x] không thấy file: %s\n' "$f" >&2; failed=1; continue; }
  abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"

  # cd vào thư mục chứa file: đây là thứ quyết định worktree nào được dùng.
  if ! (cd "$(dirname "$abs")" && "$ORCA_BIN" file open "$abs" >/dev/null 2>&1); then
    printf '[x] Orca từ chối mở: %s\n' "$abs" >&2
    printf '    thư mục này chưa nằm trong worktree nào của Orca.\n' >&2
    printf '    thêm bằng: orca repo add --path <thư mục git>\n' >&2
    failed=1
    continue
  fi
done

if [ "$failed" -eq 1 ]; then
  osascript -e 'display notification "Thư mục chưa được đăng ký trong Orca (orca repo add)" with title "Open in Orca" subtitle "Không mở được file"' >/dev/null 2>&1
  exit 1
fi

# Đưa Orca lên trước — `file open` mở tab nhưng không tự focus app.
osascript -e 'tell application "Orca" to activate' >/dev/null 2>&1 || true
