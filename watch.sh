#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# watch.sh — live reload: sửa file trong repo là hệ thống nhận NGAY khi lưu.
#
#   ./watch.sh        # sync toàn bộ 1 lần, rồi ngồi canh thay đổi (Ctrl-C dừng)
#
# Lưu file nào -> copy đúng file đó sang vị trí thật (cùng mapping với
# install.sh, gồm cả thay __TMUX_LAUNCH__ và chmod +x), rồi reload nơi cần:
#   - tmux/.tmux.conf          -> ~/.tmux.conf + `tmux source-file` ngay
#   - tmux/*.sh                -> ~/.config/tmux/ (status bar nhận ở giây kế tiếp)
#   - alacritty/alacritty.toml -> Alacritty tự live-reload config
#   - zsh/.zshrc               -> chỉ shell MỚI nhận (shell đang mở: `source ~/.zshrc`)
#   - .claude/settings.json    -> merge hook + statusLine vào ~/.claude/settings.json
#   - .claude/themes/*.json    -> ~/.claude/themes/ (chọn lại theme trong Claude Code)
#
# Khác install.sh: KHÔNG tạo backup .bak mỗi lần lưu (tránh rác) — bản cũ đã
# nằm trong git, repo là source of truth.
# ---------------------------------------------------------------------------
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

command -v fswatch >/dev/null 2>&1 || {
  warn "Thiếu fswatch — cài bằng: brew install fswatch (hoặc chạy lại ./install.sh)"
  exit 1
}

# Nạp lại config tmux nếu server đang chạy
reload_tmux() {
  tmux has-session 2>/dev/null || return 0
  if tmux source-file ~/.tmux.conf 2>/dev/null; then
    tmux display-message "watch.sh: đã reload ~/.tmux.conf"
  else
    warn "tmux source-file lỗi — kiểm tra lại .tmux.conf"
  fi
}

# Deploy MỘT file theo đúng mapping của install.sh ($1 = đường dẫn tuyệt đối)
deploy() {
  case "$1" in
    "$DOTFILES_DIR"/tmux/.tmux.conf)
      cp "$DOTFILES_DIR/tmux/.tmux.conf" ~/.tmux.conf
      log ".tmux.conf -> ~/.tmux.conf"
      reload_tmux
      ;;
    "$DOTFILES_DIR"/tmux/*.sh)
      local name; name="$(basename "$1")"
      [ -f "$DOTFILES_DIR/tmux/$name" ] || return 0  # file vừa bị xoá/đổi tên
      cp "$DOTFILES_DIR/tmux/$name" ~/.config/tmux/"$name"
      chmod +x ~/.config/tmux/"$name"
      log "$name -> ~/.config/tmux/$name"
      ;;
    "$DOTFILES_DIR"/alacritty/alacritty.toml)
      sed "s|__TMUX_LAUNCH__|$HOME/.config/tmux/tmux-launch.sh|g" \
        "$DOTFILES_DIR/alacritty/alacritty.toml" > ~/.config/alacritty/alacritty.toml
      log "alacritty.toml -> ~/.config/alacritty/alacritty.toml (Alacritty tự reload)"
      ;;
    "$DOTFILES_DIR"/zsh/.zshrc)
      cp "$DOTFILES_DIR/zsh/.zshrc" ~/.zshrc
      log ".zshrc -> ~/.zshrc (shell đang mở cần: source ~/.zshrc)"
      ;;
    "$DOTFILES_DIR"/.claude/settings.json)
      [ -f "$DOTFILES_DIR/.claude/settings.json" ] || return 0  # file vừa bị xoá/đổi tên
      mkdir -p ~/.claude
      [ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
      local tmp; tmp="$(mktemp)"
      # Merge .hooks của repo vào settings đang chạy, giữ statusLine + key khác
      if jq -s --arg cmd "$HOME/.config/tmux/claude-usage-statusline.sh" \
           '.[0] * {hooks: .[1].hooks} | .statusLine = {type:"command", command:$cmd, padding:0}' \
           ~/.claude/settings.json "$DOTFILES_DIR/.claude/settings.json" > "$tmp"; then
        mv "$tmp" ~/.claude/settings.json
        log "settings.json -> ~/.claude/settings.json (merge hook + statusLine)"
      else
        rm -f "$tmp"; warn "jq merge lỗi — kiểm tra .claude/settings.json"
      fi
      ;;
    "$DOTFILES_DIR"/.claude/themes/*.json)
      local name; name="$(basename "$1")"
      [ -f "$DOTFILES_DIR/.claude/themes/$name" ] || return 0  # file vừa bị xoá/đổi tên
      cp "$DOTFILES_DIR/.claude/themes/$name" ~/.claude/themes/"$name"
      log "$name -> ~/.claude/themes/$name (chọn lại theme trong Claude Code)"
      ;;
    *) ;;  # file lạ (swap/tmp của editor, .DS_Store, .bak...) — bỏ qua
  esac
}

# Sync toàn bộ một lần lúc khởi động cho repo và hệ thống khớp nhau
log "Sync lần đầu..."
mkdir -p ~/.config/tmux ~/.config/alacritty ~/.claude/themes
deploy "$DOTFILES_DIR/tmux/.tmux.conf"
for s in "$DOTFILES_DIR"/tmux/*.sh; do deploy "$s"; done
deploy "$DOTFILES_DIR/alacritty/alacritty.toml"
deploy "$DOTFILES_DIR/zsh/.zshrc"
deploy "$DOTFILES_DIR/.claude/settings.json"
for t in "$DOTFILES_DIR"/.claude/themes/*.json; do deploy "$t"; done

log "Đang canh $DOTFILES_DIR (tmux/ alacritty/ zsh/ .claude/) — Ctrl-C để dừng."
fswatch "$DOTFILES_DIR/tmux" "$DOTFILES_DIR/alacritty" "$DOTFILES_DIR/zsh" "$DOTFILES_DIR/.claude" |
while IFS= read -r path; do
  deploy "$path" || warn "deploy lỗi: $path"
done
