#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# orca/set-default-apps.sh — đặt "Open in Orca" làm app mặc định cho vài đuôi file.
#
#   ./orca/set-default-apps.sh          # bind các UTI trong DEFAULT_UTIS
#   ./orca/set-default-apps.sh --show   # xem app mặc định hiện tại
#   ./orca/set-default-apps.sh --unset  # trả về mặc định của macOS
#
# Đây là bước tự động thay cho thao tác tay Get Info -> Open With -> Change All.
#
# ⚠️ KHÔNG BAO GIỜ thêm `public.html` vào DEFAULT_UTIS. macOS coi việc set handler
# cho public.html LÀ đổi trình duyệt mặc định: nó bind luôn `http`, `https` và
# `com.apple.default-app.web-browser` sang app đó -> mọi link bấm ở bất cứ đâu
# đều mở bằng applet. Tệ hơn, macOS đời mới khoá việc đổi lại bằng API (duti báo
# error -54/-50), phải sửa tay plist LaunchServices mới cứu được. File .html thì
# dùng right-click -> Open With -> Open in Orca. Cuối script có bước kiểm tra
# chặn đúng trường hợp này.
#
# Vì sao phải vá Info.plist ở đây: LaunchServices CHỈ cho bind app vào UTI mà app
# đó KHAI BÁO hỗ trợ. Applet do osacompile sinh ra chỉ có
# CFBundleTypeExtensions = "*" (dạng cũ, đủ để hiện trong "Open With" nhưng
# KHÔNG đủ để làm default) -> `duti -s` chạy xong im lặng mà handler không đổi.
# Nên script thêm hẳn một CFBundleDocumentTypes entry với LSItemContentTypes
# liệt kê đúng từng UTI, rồi mới bind.
# ---------------------------------------------------------------------------
set -uo pipefail

APPLET="$HOME/Applications/Open in Orca.app"
BUNDLE_ID="com.nghiale.open-in-orca"
PLIST="$APPLET/Contents/Info.plist"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Đuôi file muốn mở bằng Orca -> UTI tương ứng (lấy bằng `mdls -name
# kMDItemContentType`). Thêm/bớt ở đây rồi chạy lại script.
#   py   public.python-script
#   txt  public.plain-text
#   md   net.daringfireball.markdown
#   sh   public.shell-script
# (html cố tình KHÔNG có — xem cảnh báo ở header.)
DEFAULT_UTIS=(
  public.python-script
  public.plain-text
  net.daringfireball.markdown
  public.shell-script
)

# Đuôi file đem đi kiểm tra kết quả, khớp với DEFAULT_UTIS ở trên.
CHECK_EXTS=(py txt md sh)

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "script này chỉ dành cho macOS."
[ -d "$APPLET" ] || die "chưa có $APPLET — chạy ./install.sh trước."

case "${1-}" in
  --show)
    command -v duti >/dev/null 2>&1 || die "thiếu duti — brew install duti"
    for ext in "${CHECK_EXTS[@]}"; do
      printf '  %-5s -> %s\n' "$ext" "$(duti -x "$ext" 2>/dev/null | sed -n 1p || echo '(không rõ)')"
    done
    exit 0 ;;
  --unset)
    command -v duti >/dev/null 2>&1 || die "thiếu duti — brew install duti"
    # Không có lệnh "gỡ bind" — trả về TextEdit, mặc định của macOS cho text.
    for uti in "${DEFAULT_UTIS[@]}"; do
      duti -s com.apple.TextEdit "$uti" all 2>/dev/null
    done
    log "Đã trả các UTI trên về TextEdit."
    exit 0 ;;
  ""|--set) ;;
  -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
  *) die "tham số lạ: $1 (dùng --show | --unset | --help)" ;;
esac

command -v duti >/dev/null 2>&1 || die "thiếu duti — brew install duti"

# 1) Khai báo UTI trong Info.plist của applet. Xoá entry cũ (nếu chạy lại) rồi
#    thêm mới để script idempotent.
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes:1" "$PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1 dict" "$PLIST" >/dev/null 2>&1
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:CFBundleTypeName string 'Orca Source File'" "$PLIST" >/dev/null 2>&1
# Editor = đủ tư cách làm app mặc định (Viewer thì chỉ mở được, không set default).
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:CFBundleTypeRole string Editor" "$PLIST" >/dev/null 2>&1
# Owner sẽ tranh quyền với app gốc; Alternate là "tôi mở được, để user chọn".
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:LSHandlerRank string Alternate" "$PLIST" >/dev/null 2>&1
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:LSItemContentTypes array" "$PLIST" >/dev/null 2>&1
for uti in "${DEFAULT_UTIS[@]}"; do
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:LSItemContentTypes: string $uti" "$PLIST" >/dev/null 2>&1
done

# 2) Sửa plist là hỏng chữ ký ad-hoc -> ký lại, không macOS từ chối chạy applet.
codesign --force --sign - "$APPLET" >/dev/null 2>&1 || warn "ký lại applet lỗi"

# 3) Nạp lại bundle để LaunchServices thấy khai báo mới TRƯỚC khi bind.
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APPLET" >/dev/null 2>&1

# 4) Bind từng UTI.
fail=0
for uti in "${DEFAULT_UTIS[@]}"; do
  duti -s "$BUNDLE_ID" "$uti" all 2>/dev/null || { warn "bind lỗi: $uti"; fail=1; }
done

# 5) Kiểm tra thật sự đã đổi chưa — `duti -s` im lặng kể cả khi không ăn.
# duti ghi qua cfprefs nên bind vừa set có thể chưa đọc lại được ngay -> flush.
killall cfprefsd 2>/dev/null || true
sleep 1

# 6) Lưới an toàn: nếu có UTI nào kéo theo vai trò trình duyệt thì gỡ ngay.
#    (Chỉ xảy ra khi ai đó thêm public.html vào DEFAULT_UTIS.)
BROWSER_HIJACK=0
for scheme in http https; do
  cur="$(duti -x "$scheme" 2>/dev/null | sed -n 3p)"
  [ "$cur" = "$BUNDLE_ID" ] && BROWSER_HIJACK=1
done
if [ "$BROWSER_HIJACK" -eq 1 ]; then
  warn "applet đã chiếm mất trình duyệt mặc định — đang trả lại Chrome..."
  duti -s com.google.Chrome http 2>/dev/null || true
  killall cfprefsd 2>/dev/null || true
  die "bỏ public.html khỏi DEFAULT_UTIS rồi chạy lại (xem cảnh báo ở đầu file)."
fi

log "App mặc định sau khi set:"
for ext in "${CHECK_EXTS[@]}"; do
  got="$(duti -x "$ext" 2>/dev/null | sed -n 3p)"
  if [ "$got" = "$BUNDLE_ID" ]; then
    printf '  \033[1;32m✓\033[0m %-5s -> Open in Orca\n' "$ext"
  else
    printf '  \033[1;31m✗\033[0m %-5s -> %s\n' "$ext" "${got:-không rõ}"
    fail=1
  fi
done

[ "$fail" -eq 0 ] || { warn "có đuôi chưa đổi được — thử logout/login rồi chạy lại."; exit 1; }
log "Xong. Double-click file .py/.txt/.md/.sh sẽ mở trong Orca."
warn ".html cố tình không set (sẽ chiếm trình duyệt mặc định) — dùng right-click -> Open With."
