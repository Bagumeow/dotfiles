# dotfiles

📖 **English** · [Tiếng Việt](README_vi.md)

Personal macOS terminal setup: **tmux + Alacritty + zsh (oh-my-zsh)**.
Goal: one command on a fresh Mac and you're ready to go, with **tmux sessions
that auto-restore after a reboot**.

## Install

```bash
git clone git@github.com:Bagumeow/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script **overwrites** every related config (even if tmux/zsh already exist).
The previous version is backed up to `*.bak.<timestamp>` before being replaced,
so nothing is lost. Safe to run repeatedly (idempotent).

When it finishes: **open a new Alacritty window** → it drops you straight into tmux.

## What's inside

| Component | File in repo | Installed to |
|---|---|---|
| tmux config | `tmux/.tmux.conf` | `~/.tmux.conf` |
| tmux launcher | `tmux/tmux-launch.sh` | `~/.config/tmux/tmux-launch.sh` |
| nyan cat status bar | `tmux/nyan-anim.sh` | `~/.config/tmux/nyan-anim.sh` |
| pwd in status bar | `tmux/tmux-pwd.sh` | `~/.config/tmux/tmux-pwd.sh` |
| Claude usage widget | `tmux/tmux-claude.sh` | `~/.config/tmux/tmux-claude.sh` |
| Claude Code statusLine | `tmux/claude-usage-statusline.sh` | `~/.config/tmux/claude-usage-statusline.sh` |
| Alacritty | `alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` |
| zsh | `zsh/.zshrc` | `~/.zshrc` |

`install.sh` also installs: Homebrew, tmux, Alacritty, JetBrainsMono Nerd font, jq,
oh-my-zsh + 3 plugins (autosuggestions, syntax-highlighting, completions),
TPM + tmux plugins (resurrect + continuum), the Alacritty theme, and the CLIs
`.zshrc` needs: **thefuck**, **python@3.12**, **kubectl**, **kubectx** (for `kubens`).

## Session auto-restore (how it works)

- **tmux-resurrect** + **tmux-continuum**: auto-save the session every **15 minutes**
  (including pane contents). Manual save/restore: `Ctrl-a Ctrl-s` / `Ctrl-a Ctrl-r`.
- **Alacritty** runs `tmux-launch.sh` directly (`[terminal.shell]`), so any window
  you open enters tmux. After a reboot, the first window starts the tmux server →
  continuum auto-restores the saved session.

> The `@continuum-boot` mechanism (sending keystrokes via AppleScript) is **not**
> used — it needs Accessibility permission and tends to nest tmux. Auto-entering
> tmux is handled by Alacritty instead.

### Want Alacritty to open automatically at login?

Add Alacritty to **System Settings → General → Login Items → "+"**.
Log in → Alacritty opens → `tmux-launch.sh` runs → your old session reappears.

## Claude usage widget in the status bar (`5h NN%`)

Shows the **remaining % of Claude Code's 5-hour rate-limit window**, plus the reset
time (e.g. `5h 70% ↻18:50`). Color-coded: green → yellow → red as it runs low. Data
older than 15 min (no Claude session running) is dimmed and prefixed with `~`.

How it works:

```
Claude Code  --(statusLine, JSON on stdin)-->  claude-usage-statusline.sh
                                                     |  writes ~/.cache/claude-usage
                                                     v
                                   tmux #(tmux-claude.sh)  -> status bar
```

`install.sh` wires the `statusLine` into `~/.claude/settings.json` (merged with jq,
other keys untouched, backed up first).

> ⚠️ **There is no absolute "tokens remaining" number.** Anthropic doesn't publish
> the Max/Pro token quotas. The most official and honest thing available is the
> **rate-limit window %** that Claude Code hands to `statusLine`
> (`rate_limits.five_hour.used_percentage`, `resets_at`). The widget only updates
> while a Claude Code session is running.

## zsh — aliases & prompt

`.zshrc` runs oh-my-zsh (theme `robbyrussell`) + 3 plugins (autosuggestions,
syntax-highlighting, completions), plus custom aliases and a custom prompt.

**Aliases**

| Alias | Command |
|---|---|
| `python` / `pip` | `python3.12` / `pip3.12` |
| `pull` `push` `commit` `add` `status` `checkout` | the matching `git` command |
| `k` `kube` | `kubectl` |
| `kns` | `kubens` (switch k8s namespace) |
| `po` `svc` `deploy` `ingress` `configmap` `secret` `pvc` | `kubectl get <resource>` |
| `describe` | `kubectl describe` |
| `use-context` | `kubectl config use-context` |
| `ala` | open a new Alacritty window in the current directory |
| `claudesudo` | `claude --dangerously-skip-permissions` |
| `unquar` | remove macOS quarantine flag (`xattr -dr com.apple.quarantine`) |

**Prompt** adapts to context:

- Inside a virtualenv: `(.venv)-user-dir(branch)$`
- Outside a venv: `user(namespace)-dir(branch)$` — `namespace` is the current k8s
  namespace (read via `kubens`, falls back to `default` if unavailable).
- `dir` only shows when **not** in `$HOME`; `(branch)` only shows inside a git repo.

**thefuck**: `eval $(thefuck --alias)` — type `fuck` to quickly fix the command you
just mistyped.

## tmux keybindings (prefix = `Ctrl-a`)

| Key | Action |
|---|---|
| `Ctrl-a` `\|` / `-` | split pane vertically / horizontally |
| `Alt + arrow` | move between panes (no prefix needed) |
| `Alt + number` | switch window |
| `Ctrl-a m` | zoom pane |
| `Ctrl-a Ctrl-s` / `Ctrl-a Ctrl-r` | save / restore session |
| `Ctrl-a r` | reload `~/.tmux.conf` |

## Restoring an old version

Each old file is backed up with a timestamp, e.g. `~/.tmux.conf.bak.20260608_2245`.
Rename it back to restore.
