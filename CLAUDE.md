# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal macOS dotfiles for a **tmux + Alacritty + zsh (oh-my-zsh)** terminal
setup. Goal: one command on a fresh Mac, plus tmux sessions that auto-restore
across reboots. There is no application code, build, or test suite — everything
is shell scripts and config files.

## Language convention

Comments and the README are written in **Vietnamese** — match that when editing
those files.

**Commit messages must ALWAYS be written in English**, regardless of the
Vietnamese style of older commits. Keep the existing `scope: description` form,
e.g. `tmux: fix status bar widget`, `zsh: add kubectl aliases`, `dotfiles: ...`.

## Commands

```bash
./install.sh                 # deploy/redeploy everything (idempotent, macOS-only)
bash -n install.sh           # syntax-check a shell script before committing
tmux source-file ~/.tmux.conf   # apply tmux edits live (or Ctrl-a r inside tmux)
```

There are no tests or linters. "Verifying a change" means `bash -n` on touched
scripts and, where practical, re-running `./install.sh` (safe to run repeatedly).

## How deployment works (the key model)

`install.sh` is the single entry point. It **copies** repo files into their live
locations under `$HOME` — it does **not** symlink. Consequences:

- Editing a file in this repo does **not** affect the running machine until you
  copy it across (re-run `./install.sh`, or `cp` the one file manually).
- Conversely, configs already live at `~/.config/tmux/*.sh`, `~/.tmux.conf`,
  `~/.config/alacritty/alacritty.toml`, `~/.zshrc` — the repo is the source of
  truth, those are deployed copies.
- Every existing target is backed up to `*.bak.<timestamp>` before being
  overwritten (see `.gitignore`); nothing is destroyed.

The list of files to copy is **hardcoded** in `install.sh` (explicit `cp` +
`chmod` lines, not a glob). **Adding or renaming a tmux script requires editing
`install.sh`'s copy/chmod block AND the file table in `README.md`** — otherwise
the new file is in the repo but never deployed.

`install.sh` also installs Homebrew packages the configs depend on (tmux,
alacritty, jetbrains-mono nerd font, jq, plus the CLIs `.zshrc` references:
thefuck, python@3.12, kubectl, kubectx), installs oh-my-zsh + 3 plugins, and
installs TPM + tmux plugins headlessly.

## Cross-file wiring (requires reading several files together)

**Alacritty → tmux auto-entry.** `alacritty.toml` sets `[terminal.shell]` to run
`tmux-launch.sh` directly (not via a login shell). The repo file contains the
placeholder `__TMUX_LAUNCH__`; `install.sh` substitutes the real path with `sed`
at install time. **Do not hardcode the path in the repo file** — keep the
placeholder. `tmux-launch.sh` attaches to an existing session, or boots the
server (letting tmux-continuum restore the last session) then attaches.

**Session persistence.** tmux-resurrect + tmux-continuum save every 15 min
(`@continuum-save-interval`) and `@continuum-restore 'on'` restores on server
start. `@continuum-boot` is intentionally **off** — auto-start is handled by
Alacritty's launcher, not continuum's keystroke mechanism (which needs
Accessibility permission and tends to nest tmux). Don't flip it on.

**Claude Code usage widget (two-process cache contract).** The tmux status bar
shows remaining % of Claude's 5-hour rate-limit window:

```
Claude Code --(statusLine, JSON on stdin)--> claude-usage-statusline.sh
                                                  | writes ~/.cache/claude-usage (TSV)
                                                  v
                          tmux status-right #(tmux-claude.sh) reads cache -> widget
```

- `claude-usage-statusline.sh` is wired into `~/.claude/settings.json` by
  `install.sh` (merged with `jq`, other keys preserved, backed up first).
- The cache file `~/.cache/claude-usage` is a 4-field TSV:
  `5h_used \t 7d_used \t 5h_reset_epoch \t written_epoch`. Both scripts must
  agree on this format — change one, change the other.
- `tmux-claude.sh` greys the widget and prefixes `~` when the cache is older
  than 15 min (no Claude session running recently). There is no absolute "tokens
  left" number — Anthropic doesn't publish Max/Pro quotas, so only the
  rate-limit percentage is shown.

**tmux status bar** (`.tmux.conf` `status-right`) shells out to the installed
scripts at `~/.config/tmux/*.sh` (`tmux-claude.sh`, `tmux-pwd.sh`,
`nyan-anim.sh`) — those paths are the deployed copies, not the repo. The
animated widgets rely on `status-interval 1`.

## Conventions in the configs

- tmux prefix is **`Ctrl-a`** (not the default `Ctrl-b`); copy-mode is **emacs**,
  not vi; panes split with `|` / `-`; Alt+arrows/Alt+number move without prefix.
- `.zshrc` overrides the oh-my-zsh theme prompt with a custom `PROMPT` and helper
  functions; it must stay **below** `source $ZSH/oh-my-zsh.sh`.
- `.zshrc` contains machine-specific absolute paths (JAVA_HOME, Maven, Antigravity
  under `/Users/nghiale/...`) and is not fully portable across usernames.
