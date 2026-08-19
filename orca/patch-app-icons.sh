#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# orca/patch-app-icons.sh — thêm app icon riêng vào carousel "App Icon" của Orca
# (Settings → Appearance → Interface → Advanced).
#
#   ./orca/patch-app-icons.sh            # vá (idempotent, đã vá thì bỏ qua)
#   ./orca/patch-app-icons.sh --status   # cho biết đã vá chưa
#   ./orca/patch-app-icons.sh --force    # phục hồi bản gốc rồi vá lại
#   ./orca/patch-app-icons.sh --revert   # trả app.asar về bản gốc
#
# VÌ SAO PHẢI VÁ APP: danh sách icon là hằng số hardcode TRONG bundle JS của Orca,
# không phải file config — không có key setting, không có CLI, không có thư mục
# icon nào để bỏ file vào. `normalizeAppIconId()` còn ép mọi id lạ về "classic",
# nên chỉ ghi appIcon = "nghia-water" vào orca-data.json là vô ích. Muốn có mục
# thứ 4 thì phải sửa 5 chỗ trong /Applications/Orca.app/Contents/Resources/app.asar:
#
#   out/main/index.js                   APP_ICON_OPTIONS   (danh sách id + label)
#                                       APP_ICON_PATHS     (id -> file cho nativeImage)
#                                       MAC_DOCK_ICON_PATHS(id -> file cho osascript)
#   out/renderer/assets/store-*.js      APP_ICON_OPTIONS   (bản copy phía renderer)
#   out/renderer/assets/Settings-*.js   APP_ICON_URLS      (ảnh preview trong carousel)
#   out/web/assets/{store,Settings}-*.js  hai chỗ trên, bản minify cho web client
#
# Vá được vì fuse `enable_embedded_asar_integrity_validation` của Electron = 0
# (đọc từ Electron Framework) -> Electron KHÔNG so hash header asar với
# ElectronAsarIntegrity trong Info.plist. Không phải sửa Info.plist, không phải
# ký lại app -> chữ ký của binary chính còn nguyên, quyền TCC/keychain không mất.
#
# CÁCH GHI LẠI ASAR: asar = [pickle header][data blob], offset của từng file là
# tương đối so với đầu data blob. Script ghi header JSON mới, copy nguyên data blob
# cũ, rồi NỐI các file sửa/thêm vào cuối — offset của mọi file cũ giữ nguyên tuyệt
# đối (append-only). Không sửa tại chỗ, không dùng `asar pack` (954/2743 file là
# `unpacked`, pack lại rất dễ sai cờ đó).
#
# VÌ SAO PHẢI append-only chứ không nén lại cho gọn: Orca đang chạy cache header
# asar trong memory nhưng đọc data bằng ĐƯỜNG DẪN. Đánh số offset lại từ đầu là
# header (cũ) trong app lệch với file (mới) trên đĩa -> app đang mở vỡ hết ảnh cho
# tới lúc restart. Giữ nguyên offset cũ thì app đang chạy vẫn đọc đúng, chỉ chưa
# thấy icon mới. Giá phải trả: bản cũ của 5 file JS nằm lại làm rác (~20MB).
#
# 3 file được thêm vào asar:
#   resources/app-icons/<id>.png       cờ `unpacked` -> nằm ở app.asar.unpacked/
#                                      (osascript/NSImage không đọc được trong asar)
#   out/renderer/assets/<id>.png       ảnh preview cho carousel (desktop)
#   out/web/assets/<id>.png            ảnh preview cho carousel (web client)
#
# ẢNH NGUỒN: orca/app-icons/<id>.png — PNG RGBA 1024x1024, alpha lấy nguyên từ
# orca-watercolor.png của Orca nên bo góc squircle + chừa lề đúng bằng icon gốc
# (vùng đặc là 878x888, lề 73px ngang / 68px dọc). Ảnh chụp nền trắng đưa vào
# thẳng sẽ ra hình vuông trắng ở Dock, phải mask trước.
#
# LƯU Ý: Orca tự update -> mỗi lần app lên version mới là app.asar bị thay bằng
# bản gốc, phải chạy lại script này (./install.sh cũng chạy). Bản gốc được cache ở
# ~/.cache/orca-app-icons/ (~120MB) để --revert/--force khỏi phải tải lại cask.
# Sau khi vá `codesign --verify /Applications/Orca.app` sẽ fail (resource seal đổi)
# và auto-update qua Squirrel có thể hỏng theo — hỏng thì:
#   ./orca/patch-app-icons.sh --revert   (hoặc brew reinstall --cask stablyai/orca/orca)
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ICON_ID="nghia-water"
ICON_LABEL="Nghia Water"
ICON_SRC="$SCRIPT_DIR/app-icons/$ICON_ID.png"

APP="/Applications/Orca.app"
ASAR="$APP/Contents/Resources/app.asar"
UNPACKED="$ASAR.unpacked"
CACHE="$HOME/.cache/orca-app-icons"
PRISTINE="$CACHE/app.asar.pristine"
PRISTINE_VER="$CACHE/app.asar.pristine.version"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

MODE="patch"
case "${1-}" in
  "")        MODE="patch" ;;
  --status)  MODE="status" ;;
  --force)   MODE="force" ;;
  --revert)  MODE="revert" ;;
  -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
  *)         die "tham số lạ: $1 (dùng --status | --force | --revert | --help)" ;;
esac

[ "$(uname -s)" = "Darwin" ] || die "script này chỉ dành cho macOS."
command -v python3 >/dev/null 2>&1 || die "thiếu python3"
[ -d "$APP" ] || die "không thấy $APP"
[ -f "$ASAR" ] || die "không thấy $ASAR"

APP_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$APP/Contents/Info.plist" 2>/dev/null || echo unknown)"

# Đã vá chưa: hỏi thẳng header asar xem có entry resources/app-icons/<id>.png,
# không grep nội dung file 120MB.
asar_has_icon() {
  ASAR="$1" ICON_ID="$ICON_ID" python3 - <<'PY'
import json, os, struct, sys
f = open(os.environ['ASAR'], 'rb')
_, _, _, strlen = struct.unpack('<IIII', f.read(16))
hdr = json.loads(f.read(strlen).decode('utf-8'))
node = hdr
for part in ('resources', 'app-icons', os.environ['ICON_ID'] + '.png'):
    node = node.get('files', {}).get(part)
    if node is None:
        sys.exit(1)
sys.exit(0)
PY
}

restore_pristine() {
  [ -f "$PRISTINE" ] || die "chưa có bản gốc ở $PRISTINE — brew reinstall --cask stablyai/orca/orca"
  local have; have="$(cat "$PRISTINE_VER" 2>/dev/null || echo unknown)"
  [ "$have" = "$APP_VER" ] || warn "bản gốc cache là version $have, app đang là $APP_VER"
  cp "$PRISTINE" "$ASAR.new" && mv "$ASAR.new" "$ASAR"
  rm -f "$UNPACKED/resources/app-icons/$ICON_ID.png"
  log "đã trả app.asar về bản gốc ($have)."
}

case "$MODE" in
  status)
    if asar_has_icon "$ASAR"; then
      log "Orca $APP_VER: ĐÃ vá — carousel có '$ICON_LABEL' (id: $ICON_ID)."
    else
      log "Orca $APP_VER: CHƯA vá — carousel chỉ có 3 icon gốc."
    fi
    [ -f "$PRISTINE" ] && log "bản gốc cache: $PRISTINE (version $(cat "$PRISTINE_VER" 2>/dev/null || echo '?'))"
    exit 0
    ;;
  revert)
    asar_has_icon "$ASAR" || { log "app.asar chưa bị vá — không có gì để trả lại."; exit 0; }
    restore_pristine
    warn "Restart Orca để nhận lại danh sách icon gốc."
    exit 0
    ;;
  force)
    asar_has_icon "$ASAR" && restore_pristine
    ;;
  patch)
    if asar_has_icon "$ASAR"; then
      log "app.asar đã có '$ICON_LABEL' — bỏ qua (dùng --force để vá lại)."
      exit 0
    fi
    ;;
esac

[ -f "$ICON_SRC" ] || die "không thấy ảnh icon $ICON_SRC"

# Tới đây app.asar là bản gốc -> cache lại để --revert/--force dùng. Chỉ copy khi
# chưa có hoặc app đã lên version khác (giữ đúng 1 bản, không phình cache).
if [ ! -f "$PRISTINE" ] || [ "$(cat "$PRISTINE_VER" 2>/dev/null || echo)" != "$APP_VER" ]; then
  log "Cache bản gốc app.asar (Orca $APP_VER)..."
  mkdir -p "$CACHE"
  cp "$ASAR" "$PRISTINE.tmp" && mv "$PRISTINE.tmp" "$PRISTINE"
  printf '%s\n' "$APP_VER" > "$PRISTINE_VER"
fi

log "Thêm app icon '$ICON_LABEL' vào Orca $APP_VER..."

ASAR="$ASAR" OUT="$ASAR.patched" UNPACKED="$UNPACKED" \
ICON_SRC="$ICON_SRC" ICON_ID="$ICON_ID" ICON_LABEL="$ICON_LABEL" \
python3 - <<'PY'
import hashlib, json, os, re, struct, sys

ASAR       = os.environ['ASAR']
OUT        = os.environ['OUT']
UNPACKED   = os.environ['UNPACKED']
ICON_SRC   = os.environ['ICON_SRC']
ICON_ID    = os.environ['ICON_ID']
ICON_LABEL = os.environ['ICON_LABEL']

BLOCK = 4194304                                    # blockSize asar vẫn dùng
VAR   = 'orca_' + re.sub(r'[^0-9A-Za-z]+', '_', ICON_ID) + '_default'
IDB   = ICON_ID.encode()
LBL   = ICON_LABEL.encode()

def die(msg):
    sys.stderr.write('[x] ' + msg + '\n')
    sys.exit(1)

def integrity(data):
    blocks = [hashlib.sha256(data[i:i + BLOCK]).hexdigest()
              for i in range(0, len(data), BLOCK)] or [hashlib.sha256(b'').hexdigest()]
    return {'algorithm': 'SHA256', 'hash': hashlib.sha256(data).hexdigest(),
            'blockSize': BLOCK, 'blocks': blocks}

f = open(ASAR, 'rb')
_, p2buf, _, strlen = struct.unpack('<IIII', f.read(16))
DATA = 8 + p2buf                                   # pickle1 (8B) + pickle2 buffer
f.seek(16)
header = json.loads(f.read(strlen).decode('utf-8'))

def node_for(path, create=False):
    node, parts = header, path.strip('/').split('/')
    for i, part in enumerate(parts):
        files = node.setdefault('files', {})
        if part not in files:
            if not create:
                return None
            files[part] = {} if i == len(parts) - 1 else {'files': {}}
        node = files[part]
    return node

def read_packed(path):
    n = node_for(path)
    if n is None or 'offset' not in n:
        die('không thấy %s trong app.asar (Orca đổi cấu trúc bundle?)' % path)
    f.seek(DATA + int(n['offset']))
    return f.read(n['size'])

def walk(node, path=''):
    for name, v in list(node.get('files', {}).items()):
        p = path + '/' + name
        if 'files' in v:
            yield from walk(v, p)
        else:
            yield p, v

# --- 1) vá JS -------------------------------------------------------------
# Mỗi rule là (regex, hàm dựng đoạn chèn). Regex khớp ĐUÔI của phần tử "blue"
# rồi chèn phần tử mới ngay sau — chạy được cả bản pretty (renderer) và bản
# minify (web). Bắt buộc khớp đúng 1 lần, khác 1 là bundle đã đổi -> dừng.
OPT  = re.compile(rb'(\{\s*id:\s*"blue",\s*label:\s*"Blue Orca"\s*\})(\s*\])')
URLM = re.compile(rb'(blue:\s*""\s*\+\s*new URL\("orca-blue-CWdjK-Ki\.png",\s*'
                  rb'import\.meta\.url\)\.href)(\s*\})')
VARS = re.compile(rb'(var orca_blue_default\$1 = \(0, path\.join\)\(__dirname, '
                  rb'"\.\./\.\./resources/app-icons/orca-blue\.png"\)'
                  rb'\.replace\("app\.asar", "app\.asar\.unpacked"\);\n)')
PTHS = re.compile(rb'(blue:\s*orca_blue_default)(?!\$)(\s*\})')
DOCK = re.compile(rb'(blue:\s*orca_blue_default\$1)(\s*\})')

MAIN     = '/out/main/index.js'
STORE    = ['/out/renderer/assets/store-CgXrfmaH.js', '/out/web/assets/store-CgXrfmaH.js']
SETTINGS = ['/out/renderer/assets/Settings-yKTVxZPa.js', '/out/web/assets/Settings-yKTVxZPa.js']
ASSETS   = ['/out/renderer/assets/', '/out/web/assets/']

def opt(m):   return m.group(1) + b',{id:"' + IDB + b'",label:"' + LBL + b'"}' + m.group(2)
def urlm(m):  return (m.group(1) + b',"' + IDB + b'":""+new URL("' + IDB +
                      b'.png",import.meta.url).href' + m.group(2))
def pths(m):  return m.group(1) + b',"' + IDB + b'":' + VAR.encode() + m.group(2)
def dock(m):  return m.group(1) + b',"' + IDB + b'":' + VAR.encode() + b'$1' + m.group(2)
def vars_(m):
    p = b'"../../resources/app-icons/' + IDB + b'.png"'
    return (m.group(1) +
            b'var ' + VAR.encode() + b' = (0, path.join)(__dirname, ' + p + b');\n' +
            b'var ' + VAR.encode() + b'$1 = (0, path.join)(__dirname, ' + p +
            b').replace("app.asar", "app.asar.unpacked");\n')

RULES = {MAIN: [(OPT, opt), (VARS, vars_), (PTHS, pths), (DOCK, dock)]}
for p in STORE:
    RULES[p] = [(OPT, opt)]
for p in SETTINGS:
    RULES[p] = [(URLM, urlm)]

overrides = {}
for path, rules in RULES.items():
    blob = read_packed(path)
    for rx, repl in rules:
        n = len(rx.findall(blob))
        if n != 1:
            die('%s: pattern %s khớp %d lần (cần đúng 1) — Orca đã đổi bundle, '
                'sửa lại regex trong script.' % (path, rx.pattern[:48], n))
        blob = rx.sub(repl, blob, count=1)
    overrides[path] = blob

# --- 2) thêm file ảnh -----------------------------------------------------
icon = open(ICON_SRC, 'rb').read()
if icon[:8] != b'\x89PNG\r\n\x1a\n':
    die('%s không phải PNG' % ICON_SRC)

for base in ASSETS:                                # ảnh preview cho carousel
    p = base + ICON_ID + '.png'
    node_for(p, create=True)
    overrides[p] = icon

# ảnh cho Dock: cờ unpacked -> ghi ra đĩa, header không giữ offset
un = node_for('/resources/app-icons/' + ICON_ID + '.png', create=True)
un.clear()
un.update({'size': len(icon), 'unpacked': True, 'integrity': integrity(icon)})
dest = os.path.join(UNPACKED, 'resources', 'app-icons')
os.makedirs(dest, exist_ok=True)
with open(os.path.join(dest, ICON_ID + '.png'), 'wb') as o:
    o.write(icon)

# --- 3) ghi lại asar ------------------------------------------------------
# append-only: data blob cũ giữ nguyên từng byte, file sửa/thêm ghi nối vào cuối.
ORIG_BLOB = os.path.getsize(ASAR) - DATA
appended, cursor = [], ORIG_BLOB
for path, v in walk(header):
    if v.get('unpacked'):
        v.pop('offset', None)
        continue
    if path not in overrides:
        continue                                   # offset cũ: không đụng tới
    data = overrides[path]
    v['size'] = len(data)
    v['integrity'] = integrity(data)
    v['offset'] = str(cursor)
    appended.append(data)
    cursor += len(data)

blob = json.dumps(header, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
pad = (4 - len(blob) % 4) % 4                      # Chromium Pickle align 4 byte
p2pay = 4 + len(blob) + pad
with open(OUT, 'wb') as o:
    o.write(struct.pack('<IIII', 4, 4 + p2pay, p2pay, len(blob)))
    o.write(blob)
    o.write(b'\0' * pad)
    f.seek(DATA)
    left = ORIG_BLOB
    while left:                                    # data blob cũ, copy nguyên xi
        chunk = f.read(min(1 << 20, left))
        if not chunk:
            die('đọc app.asar bị hụt byte')
        o.write(chunk)
        left -= len(chunk)
    for data in appended:
        o.write(data)

print('    %d file trong asar, data %.1f MB (+%.1f MB nối thêm), header %d byte'
      % (sum(1 for _ in walk(header)), cursor / 1e6,
         (cursor - ORIG_BLOB) / 1e6, len(blob)))
PY

# Kiểm lại file vừa ghi TRƯỚC khi thay: parse header, rồi hash từng file packed so
# với integrity.hash trong header (file không sửa vẫn giữ hash gốc -> sai offset
# một byte là lộ ngay).
log "Kiểm tra asar vừa ghi..."
OUT="$ASAR.patched" ICON_ID="$ICON_ID" python3 - <<'PY' || { rm -f "$ASAR.patched"; die "asar vừa ghi không hợp lệ — app.asar CHƯA bị thay, không sao."; }
import hashlib, json, os, struct, sys
f = open(os.environ['OUT'], 'rb')
_, p2buf, _, strlen = struct.unpack('<IIII', f.read(16))
DATA = 8 + p2buf
f.seek(16)
hdr = json.loads(f.read(strlen).decode('utf-8'))

def walk(node, path=''):
    for name, v in node.get('files', {}).items():
        p = path + '/' + name
        if 'files' in v:
            yield from walk(v, p)
        else:
            yield p, v

bad = packed = 0
for path, v in walk(hdr):
    if v.get('unpacked'):
        continue
    packed += 1
    f.seek(DATA + int(v['offset']))
    data = f.read(v['size'])
    if len(data) != v['size'] or hashlib.sha256(data).hexdigest() != v['integrity']['hash']:
        bad += 1
        if bad <= 5:
            print('    hash sai: ' + path)
print('    %d file packed, %d file hash sai' % (packed, bad))
sys.exit(1 if bad else 0)
PY

# Đổi bằng mv: app đang chạy vẫn giữ inode cũ nên không crash giữa phiên.
mv "$ASAR.patched" "$ASAR"
log "Xong — thêm '$ICON_LABEL' vào Settings → Appearance → Interface → Advanced."
warn "Restart Orca rồi bấm ‹ › ở carousel để chọn (không hiện label, chỉ hiện ảnh)."
warn "Chọn xong Orca ghi icon vào /Applications/Orca.app luôn (NSWorkspace setIcon)."
