#!/bin/sh
# Goku bắn Kamehameha hạ Thanos trên tmux status bar (status-interval = 1).
# Chu kỳ 16 giây: gồng chiêu "Ka..Me..Ha..Me..HAAA!!" -> tia bay dần sang phải
# -> Thanos trúng đòn chớp đỏ/vàng -> choáng váng -> lặp lại.
# Bề rộng CỐ ĐỊNH (Goku 5 + vùng tia 8 + Thanos 5 ô) nên không giật layout.

f=$(date +%s)
step=$(( f % 16 ))

# Màu tia đổi theo (vị trí + frame) -> năng lượng trông như "chảy" về phía trước
beam_color() {
  if [ $(( $1 % 2 )) -eq 0 ]; then printf '#89b4fa'; else printf '#b4f1fb'; fi
}

goku='(ò_ó)';  goku_fg='#f9e2af'      # Super Saiyan vàng
thanos='[¬_¬]'; thanos_fg='#cba6f7'   # Thanos tím, mặt khinh thường
field=''

case "$step" in
  0|1|2|3)
    # Gồng chiêu: quả cầu khí lớn dần + niệm chú
    goku='(>_<)'
    case "$step" in
      0) orb='o'; syl='Ka..' ;;
      1) orb='o'; syl='Me..' ;;
      2) orb='O'; syl='Ha..' ;;
      3) orb='O'; syl='Me..' ;;
    esac
    field="#[fg=#89dceb,bold]${orb}#[fg=#cdd6f4] ${syl}  "
    ;;
  4|5)
    # Hét chiêu thức
    field="#[fg=#89dceb,bold]@ #[fg=#f38ba8,bold]HAAA!!"
    ;;
  13|14)
    # Tia full chiều dài, Thanos trúng đòn chớp đỏ/vàng theo giây
    n=0
    while [ "$n" -lt 8 ]; do
      field="${field}#[fg=$(beam_color $(( n + f )))]═"
      n=$(( n + 1 ))
    done
    thanos='[x_x]'
    if [ $(( f % 2 )) -eq 0 ]; then thanos_fg='#f38ba8'; else thanos_fg='#f9e2af'; fi
    ;;
  15)
    # Tàn cuộc: Goku hài lòng, khói tan, Thanos choáng
    goku='(^_^)'
    thanos='[@_@]'; thanos_fg='#6c7086'
    field="#[fg=#6c7086] . o O  "
    ;;
  *)
    # 6..12: tia dài dần về phía Thanos, đệm khoảng trắng cho đủ 8 ô
    len=$(( step - 5 ))
    n=0
    while [ "$n" -lt "$len" ]; do
      field="${field}#[fg=$(beam_color $(( n + f )))]═"
      n=$(( n + 1 ))
    done
    field="${field}#[fg=#ffffff,bold]>"
    pad=$(( 7 - len ))
    while [ "$pad" -gt 0 ]; do
      field="${field} "
      pad=$(( pad - 1 ))
    done
    ;;
esac

printf '#[fg=%s,bold]%s%s#[fg=%s,bold]%s' "$goku_fg" "$goku" "$field" "$thanos_fg" "$thanos"
