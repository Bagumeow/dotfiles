#!/bin/bash
# Widget tmux: THANH (bar) hiện % CÒN LẠI của cửa sổ rate-limit 5h của Claude Code
# + % còn lại của cửa sổ 7 ngày (chỉ hiện SỐ, không bar).
# Đọc cache do claude-usage-statusline.sh ghi. Bar đầy = còn nhiều, vơi = sắp hết.
# Tô màu theo mức còn lại; làm mờ + thêm dấu ~ nếu dữ liệu cũ (không có session
# Claude nào đang chạy gần đây).
cache="$HOME/.cache/claude-usage"
bg="#1e1e2e"
empty_col="#45475a"   # màu ô rỗng (xám tối, mờ hơn nền một chút)
segments=10           # số ô của thanh bar (mỗi ô = 10%)

[ -f "$cache" ] || exit 0
# Tách TSV bằng tay (read gộp 2 tab liền nhau -> field rỗng làm lệch cột)
line="$(<"$cache")"
five=${line%%$'\t'*};  rest=${line#*$'\t'}
seven=${rest%%$'\t'*}; rest=${rest#*$'\t'}
reset=${rest%%$'\t'*}; ts=${rest#*$'\t'}
[ -z "$five" ] && exit 0

now="$(date +%s)"
age=$(( now - ${ts:-0} ))

# màu theo % còn lại (dùng chung cho 5h lẫn 7d)
level_color() {
  if   [ "$1" -le 15 ]; then printf '#f38ba8'   # đỏ: sắp hết
  elif [ "$1" -le 40 ]; then printf '#f9e2af'   # vàng
  else                       printf '#a6e3a1'   # xanh: thoải mái
  fi
}

# % còn lại của cửa sổ 5h, kẹp trong [0,100]
rem5=$(( 100 - five ))
[ "$rem5" -lt 0 ]   && rem5=0
[ "$rem5" -gt 100 ] && rem5=100
col="$(level_color "$rem5")"

# % còn lại của cửa sổ 7 ngày (nếu cache có) — chỉ số, không bar
rem7=""
if [ -n "$seven" ]; then
  rem7=$(( 100 - seven ))
  [ "$rem7" -lt 0 ]   && rem7=0
  [ "$rem7" -gt 100 ] && rem7=100
fi

# số ô được tô đầy (làm tròn)
filled=$(( (rem5 * segments + 50) / 100 ))
[ "$filled" -gt "$segments" ] && filled=$segments
empty=$(( segments - filled ))

# dựng chuỗi ô đầy (█) và ô rỗng (░)
bar_full=""; i=0
while [ "$i" -lt "$filled" ]; do bar_full="${bar_full}█"; i=$((i+1)); done
bar_empty=""; i=0
while [ "$i" -lt "$empty" ];  do bar_empty="${bar_empty}░"; i=$((i+1)); done

# giờ reset
rt=""
[ -n "$reset" ] && rt=" ↻$(date -r "$reset" +%H:%M 2>/dev/null)"

# dữ liệu cũ hơn 15' -> coi như stale: cả bar lẫn chữ đều mờ, thêm dấu ~
if [ "$age" -gt 900 ]; then
  dim="#6c7086"
  seg7=""
  [ -n "$rem7" ] && seg7=" 7d ${rem7}%"
  printf '#[fg=%s,bg=%s] ~5h %s%s %d%%%s%s ' \
    "$dim" "$bg" "$bar_full" "$bar_empty" "$rem5" "$seg7" "$rt"
else
  # phần đầy theo màu mức còn lại, phần rỗng xám tối; 7d tô màu theo mức của nó
  seg7=""
  [ -n "$rem7" ] && seg7=" #[fg=$(level_color "$rem7")]7d ${rem7}%"
  printf '#[fg=%s,bg=%s] 5h %s#[fg=%s]%s#[fg=%s] %d%%%s#[fg=%s]%s ' \
    "$col" "$bg" "$bar_full" "$empty_col" "$bar_empty" "$col" "$rem5" "$seg7" "$col" "$rt"
fi
