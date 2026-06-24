# dotfiles

📖 [English](README.md) · **Tiếng Việt**

Setup terminal cá nhân cho macOS: **tmux + Alacritty + zsh (oh-my-zsh)**.
Mục tiêu: cài 1 phát trên máy Mac mới là dùng được ngay, và **session tmux tự
khôi phục sau khi tắt/mở máy**.

## Cài đặt

```bash
git clone git@github.com:Bagumeow/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Script sẽ **ghi đè** mọi config liên quan (kể cả khi máy đã có sẵn tmux/zsh).
Bản cũ được backup thành `*.bak.<timestamp>` trước khi ghi đè, nên không mất gì.
Chạy lại nhiều lần đều an toàn (idempotent).

Sau khi xong: **mở một cửa sổ Alacritty mới** → tự vào tmux.

## Có gì bên trong

| Thành phần | File trong repo | Cài tới |
|---|---|---|
| tmux config | `tmux/.tmux.conf` | `~/.tmux.conf` |
| tmux launcher | `tmux/tmux-launch.sh` | `~/.config/tmux/tmux-launch.sh` |
| Goku kamehameha status bar | `tmux/kamehameha.sh` | `~/.config/tmux/kamehameha.sh` |
| pwd ở status bar | `tmux/tmux-pwd.sh` | `~/.config/tmux/tmux-pwd.sh` |
| widget usage Claude | `tmux/tmux-claude.sh` | `~/.config/tmux/tmux-claude.sh` |
| statusLine Claude Code | `tmux/claude-usage-statusline.sh` | `~/.config/tmux/claude-usage-statusline.sh` |
| theme Claude Code | `.claude/themes/*.json` | `~/.claude/themes/` |
| hook/statusLine Claude Code | `.claude/settings.json` | `~/.claude/settings.json` (merge jq) |
| Alacritty | `alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` |
| Hammerspoon (kêu phím mũi tên) | `hammerspoon/init.lua` | `~/.hammerspoon/init.lua` |
| zsh | `zsh/.zshrc` | `~/.zshrc` |

`install.sh` còn tự cài: Homebrew, tmux, Alacritty, Hammerspoon, font JetBrainsMono Nerd, jq,
fswatch (cho `watch.sh`), oh-my-zsh + 3 plugin (autosuggestions,
syntax-highlighting, completions), TPM + plugin tmux (resurrect + continuum),
theme Alacritty, và các CLI mà `.zshrc` cần: **thefuck**, **python@3.12**,
**kubectl**, **kubectx** (cho `kubens`).

## Live reload khi đang sửa repo này (`watch.sh`)

`install.sh` **copy** file (không symlink), nên sửa file trong repo sẽ không có
tác dụng cho tới khi copy sang. Khi đang vọc repo, chạy:

```bash
./watch.sh
```

Nó sync toàn bộ một lần, rồi canh `tmux/`, `alacritty/` và `zsh/`: mỗi lần lưu
file nào là copy đúng file đó sang vị trí thật (cùng mapping với `install.sh`,
gồm cả thay `__TMUX_LAUNCH__` và `chmod +x`) và reload nơi nào được:

| File vừa lưu | Chuyện gì xảy ra |
|---|---|
| `tmux/.tmux.conf` | copy + `tmux source-file` → áp dụng ngay lập tức |
| `tmux/*.sh` | copy + `chmod +x` → status bar nhận ở giây kế tiếp |
| `alacritty/alacritty.toml` | copy (đã thay placeholder) → Alacritty tự live-reload |
| `zsh/.zshrc` | copy → chỉ shell **MỚI** nhận (shell đang mở: `source ~/.zshrc`) |
| `hammerspoon/init.lua` | copy → Hammerspoon tự reload (dùng `pathwatcher` sẵn có) |
| `.claude/settings.json` | merge jq vào `~/.claude/settings.json` (hook + statusLine) |
| `.claude/themes/*.json` | copy → chọn lại theme trong Claude Code để áp dụng |

Khác `install.sh`: **không** tạo backup `.bak` mỗi lần lưu — bản cũ đã nằm
trong git. Cần `fswatch` (`install.sh` tự cài).

## Tự khôi phục session (cách hoạt động)

- **tmux-resurrect** + **tmux-continuum**: tự lưu session mỗi **15 phút**
  (và lưu cả nội dung pane). Lưu/khôi phục tay: `Ctrl-a Ctrl-s` / `Ctrl-a Ctrl-r`.
- **Alacritty** chạy thẳng `tmux-launch.sh` (`[terminal.shell]`), nên mở cửa sổ
  nào cũng vào tmux. Sau reboot, lần mở đầu tiên sẽ khởi động tmux server →
  continuum tự khôi phục session đã lưu.

> Không dùng cơ chế `@continuum-boot` (gõ phím qua AppleScript) vì cần quyền
> Accessibility và dễ gây lồng tmux. Việc auto-vào-tmux do Alacritty đảm nhận.

**Thư mục mặc định cho session mới.** `tmux-launch.sh` có biến `DEFAULT_DIR`
(hiện là `~/my-workspace/loan-factory/ai-stack`) và `cd` vào đó trước khi tạo
session — nên lần mở mới mà không có gì để khôi phục sẽ vào thẳng thư mục này.
Session được khôi phục vẫn giữ thư mục cũ của nó. Muốn mở session mới ở thư mục
này bất cứ lúc nào: bấm `Ctrl-a C-c`.

### Muốn Alacritty tự mở ngay khi đăng nhập máy?

Thêm Alacritty vào **System Settings → General → Login Items → "+"**.
Đăng nhập → Alacritty mở → `tmux-launch.sh` chạy → session cũ hiện lại.

## Widget usage Claude ở status bar (`5h NN% 7d NN%`)

Hiện **% CÒN LẠI của cửa sổ rate-limit 5 giờ** của Claude Code (dạng bar) và
của **cửa sổ 7 ngày** (chỉ số, không bar), kèm giờ reset
(vd `5h ████████░░ 80% 7d 88% ↻14:40`). Tô màu: xanh → vàng → đỏ khi sắp hết. Dữ liệu cũ hơn
15' (không có session Claude nào chạy) sẽ bị làm mờ + thêm dấu `~`.

Cách hoạt động:

```
Claude Code  --(statusLine, stdin JSON)-->  claude-usage-statusline.sh
                                                   |  ghi ~/.cache/claude-usage
                                                   v
                                   tmux #(tmux-claude.sh)  -> status bar
```

`install.sh` tự gắn `statusLine` vào `~/.claude/settings.json` (merge bằng jq,
không đụng các key khác; có backup).

> ⚠️ **Không có "số token còn lại" tuyệt đối.** Anthropic không công bố hạn mức
> token của Max/Pro. Thứ chính thống & trung thực nhất là **% cửa sổ rate-limit**
> mà Claude Code đưa cho `statusLine` (`rate_limits.five_hour.used_percentage`,
> `resets_at`). Widget chỉ cập nhật khi có session Claude Code đang chạy.

## Âm thanh báo

Hai thứ báo bằng tiếng, không liên quan nhau:

- **Hook Claude Code** (`.claude/settings.json` → merge vào `~/.claude/settings.json`):
  hook `Stop` kêu `Glass` khi Claude trả lời xong, hook `Notification` kêu `Pop`
  khi cần mình nhập liệu/cấp quyền. Chỉ áp dụng trong session Claude.
  `install.sh`/`watch.sh` merge `.hooks` của repo vào settings đang chạy bằng `jq`,
  giữ nguyên `statusLine` và các key khác.
- **Hammerspoon** (`hammerspoon/init.lua` → `~/.hammerspoon/init.lua`): kêu `Tink`
  mỗi khi bấm **phím mũi tên** (↑/↓/←/→) lúc app đích đang front (mặc định Alacritty
  và VS Code — sửa `targetApps`). Dùng `eventtap` cho phím đi qua (không vỡ
  auto-repeat), bỏ qua sự kiện giữ phím, và chạy `afplay` nền mỗi lần bấm nên bấm
  nhanh vẫn kêu đủ.

> ⚠️ **Hammerspoon cần quyền Accessibility** — mở Hammerspoon 1 lần rồi bật nó ở
> **System Settings → Privacy & Security → Accessibility**. Nó không biết "đang
> focus session Claude" hay "đang cuộn lịch sử zsh", nên sẽ kêu với *mọi* ↑/↓
> trong Alacritty, không riêng gì Claude Code.

## zsh — alias & prompt

`.zshrc` chạy oh-my-zsh (theme `robbyrussell`) + 3 plugin (autosuggestions,
syntax-highlighting, completions), thêm alias và prompt tuỳ biến.

**Alias**

| Alias | Lệnh |
|---|---|
| `python` / `pip` | `python3.12` / `pip3.12` |
| `pull` `push` `commit` `add` `status` `checkout` | lệnh `git` tương ứng |
| `k` `kube` | `kubectl` |
| `kns` | `kubens` (đổi k8s namespace) |
| `po` `svc` `deploy` `ingress` `configmap` `secret` `pvc` | `kubectl get <resource>` |
| `describe` | `kubectl describe` |
| `use-context` | `kubectl config use-context` |
| `ala` | mở cửa sổ Alacritty mới ở thư mục hiện tại |
| `claudesudo` | `claude --dangerously-skip-permissions` |
| `unquar` | gỡ cờ quarantine của macOS (`xattr -dr com.apple.quarantine`) |

**Prompt** tự đổi theo ngữ cảnh:

- Trong virtualenv: `(.venv)-user-dir(branch)$`
- Ngoài venv: `user(namespace)-dir(branch)$` — `namespace` là k8s namespace hiện
  tại (đọc qua `kubens`, fallback `default` nếu không có).
- `dir` chỉ hiện khi **không** ở `$HOME`; `(branch)` chỉ hiện khi đang trong git repo.

**thefuck**: `eval $(thefuck --alias)` — gõ `fuck` để sửa nhanh lệnh vừa gõ sai.

## Phím tắt tmux (prefix = `Ctrl-a`)

| Phím | Tác dụng |
|---|---|
| `Ctrl-a` `v` / `h` | chia pane dọc / ngang |
| `Alt + mũi tên` | chuyển pane (không cần prefix) |
| `Alt + số` | chuyển window |
| `Ctrl-a C-c` | tạo session mới ở thư mục mặc định (`ai-stack`) |
| `Ctrl-a m` | zoom pane |
| `Ctrl-a Ctrl-s` / `Ctrl-a Ctrl-r` | lưu / khôi phục session |
| `Ctrl-a r` | reload `~/.tmux.conf` |

## Gỡ / khôi phục bản cũ

Mỗi file cũ được backup kèm timestamp, ví dụ `~/.tmux.conf.bak.20260608_2245`.
Đổi tên lại để khôi phục.
