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
| Goku kamehameha status bar | `tmux/kamehameha.sh` | `~/.config/tmux/kamehameha.sh` |
| pwd in status bar | `tmux/tmux-pwd.sh` | `~/.config/tmux/tmux-pwd.sh` |
| Claude usage widget | `tmux/tmux-claude.sh` | `~/.config/tmux/tmux-claude.sh` |
| Claude Code statusLine | `tmux/claude-usage-statusline.sh` | `~/.config/tmux/claude-usage-statusline.sh` |
| Claude Code theme | `.claude/themes/*.json` | `~/.claude/themes/` |
| Claude Code hooks/statusLine | `.claude/settings.json` | `~/.claude/settings.json` (jq-merged) |
| Alacritty | `alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` |
| Hammerspoon (arrow-key sound) | `hammerspoon/init.lua` | `~/.hammerspoon/init.lua` |
| Arrow-key sound files | `audio/*.mp3` | `~/.hammerspoon/` |
| Orca keybindings | `orca/keybindings.json` | `~/.orca/keybindings.json` |
| Orca settings (theme, opacity) | `orca/settings.json` | `orca-data.json` of the active profile (jq-merged) |
| zsh | `zsh/.zshrc` | `~/.zshrc` |

`install.sh` also installs: Homebrew, tmux, Alacritty, Hammerspoon, Orca, JetBrainsMono Nerd font, jq,
fswatch (for `watch.sh`), oh-my-zsh + 3 plugins (autosuggestions,
syntax-highlighting, completions), TPM + tmux plugins (resurrect + continuum),
the Alacritty theme, and the CLIs `.zshrc` needs: **thefuck**, **python@3.12**,
**kubectl**, **kubectx** (for `kubens`).

**Orca** comes from its own tap, so `install.sh` taps it first:

```bash
brew tap stablyai/orca
brew install --cask stablyai/orca/orca
```

(The `orca` cask in homebrew-cask is plotly's unrelated tool, and Homebrew doesn't
auto-tap third-party taps.) The install is skipped when `/Applications/Orca.app`
already exists, e.g. installed from [onorca.dev](https://onorca.dev) — the app
self-updates, so brew may report an older version. Restart Orca to pick up new
keybindings and Window Blur.

Orca has no CLI for settings, and its settings live **inside the state file**
`~/Library/Application Support/orca/profiles/<activeProfileId>/orca-data.json`
(together with projects, worktrees and session state), so the repo can't just copy
that file. `orca/settings.json` holds only the keys we own and `install.sh`/`watch.sh`
`jq`-merge them in, leaving the other ~180 settings and all state untouched:

| Key | Value | Meaning |
|---|---|---|
| `theme` | `dark` | app theme |
| `terminalThemeDark` | `Tokyo Night` | terminal theme (builtins include Gruvbox, Catppuccin Mocha/Latte, One Dark, Solarized; Warp themes can be imported into `terminalCustomThemes`) |
| `terminalBackgroundOpacity` | `0.9` | terminal background transparency — 1 opaque, 0 fully transparent |
| `windowBackgroundBlur` | `true` | macOS vibrancy behind the window (**needs an app restart**) |

> ⚠️ **The merge is skipped while Orca is running** — the app keeps its state in
> memory and rewrites `orca-data.json`, so it would overwrite the change. Quit Orca
> (`Cmd-Q`), then run `./install.sh`. The previous `orca-data.json` is copied to
> `*.bak.<timestamp>` first.

## Live reload while editing this repo (`watch.sh`)

`install.sh` **copies** files (no symlinks), so editing a file in the repo does
nothing until it's copied across. While working on the repo, run:

```bash
./watch.sh
```

It syncs everything once, then watches `tmux/`, `alacritty/` and `zsh/`: every
save copies that file to its live location (same mapping as `install.sh`,
including the `__TMUX_LAUNCH__` substitution and `chmod +x`) and reloads where
possible:

| File saved | What happens |
|---|---|
| `tmux/.tmux.conf` | copied + `tmux source-file` → applies instantly |
| `tmux/*.sh` | copied + `chmod +x` → status bar picks it up the next second |
| `alacritty/alacritty.toml` | copied (placeholder substituted) → Alacritty live-reloads itself |
| `zsh/.zshrc` | copied → **new** shells only (existing ones: `source ~/.zshrc`) |
| `hammerspoon/init.lua` | copied → Hammerspoon auto-reloads (built-in `pathwatcher`) |
| `audio/*.mp3` | copied → used on the next keypress (no reload needed) |
| `.claude/settings.json` | jq-merged into `~/.claude/settings.json` (hooks + statusLine) |
| `.claude/themes/*.json` | copied → re-pick the theme in Claude Code to apply |
| `orca/keybindings.json` | copied → **restart Orca** to pick it up |
| `orca/settings.json` | `jq`-merged into the active profile's `orca-data.json` (**skipped while Orca runs**) |

Unlike `install.sh`, it does **not** create `.bak` backups on every save — the
old version is already in git. Requires `fswatch` (installed by `install.sh`).

## Session auto-restore (how it works)

- **tmux-resurrect** + **tmux-continuum**: auto-save the session every **15 minutes**
  (including pane contents). Manual save/restore: `Ctrl-a Ctrl-s` / `Ctrl-a Ctrl-r`.
- **Alacritty** runs `tmux-launch.sh` directly (`[terminal.shell]`), so any window
  you open enters tmux. After a reboot, the first window starts the tmux server →
  continuum auto-restores the saved session.

> The `@continuum-boot` mechanism (sending keystrokes via AppleScript) is **not**
> used — it needs Accessibility permission and tends to nest tmux. Auto-entering
> tmux is handled by Alacritty instead.

**Default directory for new sessions.** `tmux-launch.sh` has a `DEFAULT_DIR`
(currently `~/my-workspace/loan-factory/ai-stack`) and `cd`s into it before
creating a session — so a fresh start with nothing to restore opens there.
Restored sessions keep their own saved directory. To open a new session in that
dir on demand at any time, press `Ctrl-a C-c`.

### Want Alacritty to open automatically at login?

Add Alacritty to **System Settings → General → Login Items → "+"**.
Log in → Alacritty opens → `tmux-launch.sh` runs → your old session reappears.

## Claude usage widget in the status bar (`5h NN% 7d NN%`)

Shows the **remaining % of Claude Code's 5-hour rate-limit window** (as a bar)
and of the **7-day window** (number only), plus the reset time (e.g.
`5h ████████░░ 80% 7d 88% ↻14:40`). Color-coded: green → yellow → red as it runs low. Data
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

## Sound cues

Two unrelated bits of audio feedback:

- **Claude Code hooks** (`.claude/settings.json` → merged into `~/.claude/settings.json`):
  a `Stop` hook plays `Glass` when Claude finishes a reply, and a `Notification`
  hook plays `Pop` when it needs your input/permission. These are scoped to Claude
  sessions. `install.sh`/`watch.sh` `jq`-merge the repo's `.hooks` into your live
  settings, leaving `statusLine` and other keys untouched.
- **Hammerspoon** (`hammerspoon/init.lua` → `~/.hammerspoon/init.lua`): plays a short
  sound (`audio/gta_sa_effect_4.mp3` → `~/.hammerspoon/gta_sa_effect_4.mp3`; falls back to `Tink` if
  missing — point `init.lua` at another `audio/*.mp3` to change it) on every **arrow
  key** (↑/↓/←/→) while a target app is frontmost (Alacritty and VS Code by default —
  edit `targetApps`). It uses an `eventtap` that passes the key through (no key-repeat
  break), skips held-key auto-repeat, and fires a detached `afplay` per press so fast
  taps each sound.

> ⚠️ **Hammerspoon needs Accessibility permission** — open Hammerspoon once and
> grant it under **System Settings → Privacy & Security → Accessibility**.
> It can't tell "a Claude session is focused" from "scrolling zsh history", so it
> beeps on *all* ↑/↓ in Alacritty, not just inside Claude Code.

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
- Outside a venv: `user(project:namespace)-dir(branch)$` — `project` is the GCP
  project parsed from the current kube context's GKE cluster name
  (`gke_<project>_<region>_<cluster>`; falls back to the raw context name),
  `namespace` is the current k8s namespace (read via `kubens`, falls back to
  `default` if unavailable).
- `dir` only shows when **not** in `$HOME`; `(branch)` only shows inside a git repo.

**thefuck**: `eval $(thefuck --alias)` — type `fuck` to quickly fix the command you
just mistyped.

## tmux keybindings (prefix = `Ctrl-a`)

| Key | Action |
|---|---|
| `Ctrl-a` `v` / `h` | split pane vertically / horizontally |
| `Alt + arrow` | move between panes (no prefix needed) |
| `Alt + number` | switch window |
| `Ctrl-a C-c` | new session in the default dir (`ai-stack`) |
| `Ctrl-a m` | zoom pane |
| `Ctrl-a Ctrl-s` / `Ctrl-a Ctrl-r` | save / restore session |
| `Ctrl-a r` | reload `~/.tmux.conf` |

## Restoring an old version

Each old file is backed up with a timestamp, e.g. `~/.tmux.conf.bak.20260608_2245`.
Rename it back to restore.
