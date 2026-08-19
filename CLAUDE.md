# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal macOS dotfiles for a **tmux + Alacritty + zsh (oh-my-zsh)** terminal
setup. Goal: one command on a fresh Mac, plus tmux sessions that auto-restore
across reboots. There is no application code, build, or test suite — everything
is shell scripts and config files.

## Language convention

Code comments are written in **Vietnamese** — match that when editing scripts.
The README is bilingual: **`README.md` is English, `README_vi.md` is Vietnamese**
(each links to the other at the top). Keep them in sync — a change to one must be
mirrored in the other.

**Commit messages must ALWAYS be written in English**, regardless of the
Vietnamese style of older commits. Keep the existing `scope: description` form,
e.g. `tmux: fix status bar widget`, `zsh: add kubectl aliases`, `dotfiles: ...`.

## Commands

```bash
./install.sh                 # deploy/redeploy everything (idempotent, macOS-only)
./watch.sh                   # live reload: watch the repo, auto-deploy each saved file
bash -n install.sh           # syntax-check a shell script before committing
tmux source-file ~/.tmux.conf   # apply tmux edits live (or Ctrl-a r inside tmux)
```

There are no tests or linters. "Verifying a change" means `bash -n` on touched
scripts and, where practical, re-running `./install.sh` (safe to run repeatedly).

## How deployment works (the key model)

`install.sh` is the single entry point. It **copies** repo files into their live
locations under `$HOME` — it does **not** symlink. Consequences:

- Editing a file in this repo does **not** affect the running machine until you
  copy it across (re-run `./install.sh`, `cp` the one file manually, or keep
  `./watch.sh` running — it auto-deploys every save with the same mapping, no
  `.bak` backups).
- Conversely, configs already live at `~/.config/tmux/*.sh`, `~/.tmux.conf`,
  `~/.config/alacritty/alacritty.toml`, `~/.zshrc` — the repo is the source of
  truth, those are deployed copies.
- Every existing target is backed up to `*.bak.<timestamp>` before being
  overwritten (see `.gitignore`); nothing is destroyed.

The list of files to copy is **hardcoded** in `install.sh` (explicit `cp` +
`chmod` lines, not a glob). **Adding or renaming a tmux script requires editing
`install.sh`'s copy/chmod block AND the file tables in both `README.md` and
`README_vi.md`** — otherwise the new file is in the repo but never deployed.

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

**Default directory for new sessions.** `tmux-launch.sh` `cd`s into `DEFAULT_DIR`
(guarded by `[ -d ]`) before creating a session, and `.tmux.conf` binds
`Ctrl-a C-c` to `new-session -c <same path>`. **That absolute path is duplicated
in both files — change both together.** It only affects genuinely new sessions;
continuum-restored sessions keep their own saved directories.

**Session persistence.** tmux-resurrect + tmux-continuum save every 15 min
(`@continuum-save-interval`) and `@continuum-restore 'on'` restores on server
start. `@continuum-boot` is intentionally **off** — auto-start is handled by
Alacritty's launcher, not continuum's keystroke mechanism (which needs
Accessibility permission and tends to nest tmux). Don't flip it on.

**Claude Code usage widget (two-process cache contract).** The tmux status bar
shows remaining % of Claude's 5-hour rate-limit window (bar + number) and of
the 7-day window (number only):

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
`kamehameha.sh`) — those paths are the deployed copies, not the repo. The
animated widgets rely on `status-interval 1`.

**Orca (stably.ai desktop app) — only `keybindings.json` is ours.** Orca keeps
three separate things on disk; of those, the repo manages exactly one (it also
owns a few settings keys, a patched-in app icon, and the Finder shim — all three
covered further down):

- `~/.orca/keybindings.json` — hand-edited, **in the repo** (`orca/keybindings.json`),
  copied verbatim by `install.sh`.
- `~/.orca/agent-hooks/{claude,codex,cursor}-hook.sh` — **generated by Orca**,
  version-matched to the app, and referenced by absolute path from 13 hook events
  in `~/.claude/settings.json`. Don't commit or hand-edit them; Orca rewrites them.
- `~/Library/Application Support/orca/` — runtime state and **secrets**
  (`orca-runtime.json` holds an `authToken`, plus `orca-e2ee-keypair.json`,
  `account-session.json.enc`). Never commit anything from here.

App settings (theme, opacity, fonts, per-agent flags — ~180 keys) live under
`.settings` **inside** `profiles/<activeProfileId>/orca-data.json`, mixed with
projects/worktrees/session state, and Orca exposes **no CLI** to set them
(`orca agent-context --json` has 228 commands, none for settings). So the repo owns
only a few keys in `orca/settings.json` and `install.sh`/`watch.sh` `jq`-merge them
(`.[0] * {settings: .[1]}` — recursive, so other keys survive) into the profile
resolved from `orca-profile-index.json`'s `activeProfileId`. **Both scripts skip the
merge while Orca is running** (`pgrep -x Orca`) because the app rewrites that file
from memory. `terminalBackgroundOpacity` < 1 gives a translucent terminal background;
`windowBackgroundBlur` adds macOS vibrancy and needs an app restart.

The app is installed in step 1 from its **own tap** — `brew tap stablyai/orca` then
`brew install --cask stablyai/orca/orca`. The tap is required because homebrew-cask's
`orca` is plotly's unrelated tool and Homebrew won't auto-tap third-party taps; the
install is skipped when `/Applications/Orca.app` exists (the app self-updates, so it
can be ahead of the cask version). The config block in step 8 is skipped entirely
unless `/Applications/Orca.app` or `~/.orca` exists. Neither keybindings nor settings
can be live-reloaded — Orca has to be restarted, so `watch.sh` only stages the files.

**The custom app icon is a binary patch of `app.asar`, not a setting.** The **App
Icon** carousel (Settings → Appearance → Interface → Advanced) is driven by
`APP_ICON_OPTIONS`, a hardcoded array in Orca's JS bundle, and `normalizeAppIconId()`
coerces any unknown id back to `classic` — so writing `appIcon` into `orca-data.json`
alone does nothing. `orca/patch-app-icons.sh` adds a fourth entry by rewriting
`Orca.app/Contents/Resources/app.asar`, and `install.sh` runs it **before**
`apply-settings.sh` (the `appIcon` key in `orca/settings.json` is only valid after the
patch). Five spots, in three logical files plus their minified web-bundle twins:

| Spot | File in the asar | What it feeds |
|---|---|---|
| `APP_ICON_OPTIONS` | `out/main/index.js`, `out/{renderer,web}/assets/store-*.js` | the id/label list |
| `APP_ICON_PATHS` | `out/main/index.js` | id → PNG for `nativeImage` |
| `MAC_DOCK_ICON_PATHS` | `out/main/index.js` | id → PNG for the `osascript` that persists the Dock icon |
| `APP_ICON_URLS` | `out/{renderer,web}/assets/Settings-*.js` | the carousel preview `<img>` |

Facts the script depends on — check these first if it ever breaks:

- Electron's `enable_embedded_asar_integrity_validation` fuse is **0** in Orca's
  build (read from `Electron Framework`), so the `ElectronAsarIntegrity` hash in
  `Info.plist` is not enforced and the app is **not re-signed** — the main binary's
  signature stays valid, so TCC/keychain permissions survive. `codesign --verify` on
  the bundle does start failing; Squirrel auto-update may break with it.
- asar layout is `[Chromium Pickle header][data blob]` with per-file offsets
  **relative to the data blob** (and stored as strings). Data starts at
  `8 + pickle2BufferSize` — **not** `16 + jsonLength`, that misses the 4-byte
  alignment padding. It does not use `asar pack`, because 954 of 2743 entries are
  flagged `unpacked` and repacking would lose those flags.
- The rewrite is deliberately **append-only**: the old data blob is copied byte for
  byte and the patched/new files go after it, so every pre-existing offset survives
  unchanged. Renumbering offsets compactly also works and saves ~20 MB, but a
  **running** Orca caches the asar header in memory while reading data **by path** —
  with renumbered offsets its stale header points into the wrong bytes and every icon
  in the app turns into a broken image until restart. Append-only keeps the live app
  fully consistent (it just doesn't see the new entry yet). The cost is the superseded
  copies of the 5 JS files left behind as dead space (128 MB → 148 MB).
- The Dock icon PNG must be `unpacked` (`app.asar.unpacked/resources/app-icons/`) —
  `osascript`/`NSImage` cannot read inside an asar. The carousel preview PNG must be
  **packed**, since it is fetched as a URL relative to the renderer chunk.
- Icon art is `orca/app-icons/*.png`: 1024×1024 RGBA, alpha copied verbatim from
  Orca's `orca-watercolor.png` so the squircle and padding (solid area 878×888, inset
  73px horizontal / 68px vertical) match the stock icons. An opaque photo would render
  as a white square in the Dock.
- Orca self-updates and each update restores the stock `app.asar`, so the patch must
  be re-applied; the script is idempotent and caches the pristine asar in
  `~/.cache/orca-app-icons/` for `--revert`/`--force`. `watch.sh` deliberately does
  **not** run it in the initial sync (it rewrites a 120 MB file in `/Applications`) —
  only when an icon PNG or the script itself is edited.
- The carousel renders the image only, no label, so a `label` is visible solely in the
  settings search index.

**Opening a file in Orca from Finder needs a shim — the app cannot do it.**
Orca.app's `Info.plist` declares **no `CFBundleDocumentTypes`** (and no
`CFBundleURLTypes`), so LaunchServices has nothing to bind: Orca never appears in
Finder's *Open With*, double-click can't route to it, and `open -a Orca <file>`
merely focuses the app. The only ingress is the CLI `orca file open`, which accepts
a path only **inside a registered worktree** and resolves that worktree from the
**current directory** — calling it from a different worktree fails with
`invalid_relative_path`. Two repo files bridge this:

- `orca/open-in-orca.sh` → `~/.config/orca/open-in-orca.sh`. It `cd`s into the
  file's own directory — that `cd` is the entire trick, it's what makes Orca pick
  the right worktree — boots the runtime if `orca status` fails, calls
  `orca file open`, then `activate`s Orca (the CLI opens a tab but doesn't focus
  the app). Failures go to a `display notification`, because nothing launched from
  Finder has a terminal to print to.
- `orca/open-in-orca.applescript` → `install.sh` `osacompile`s it into
  `~/Applications/Open in Orca.app`. AppleScript applets declare
  `CFBundleTypeExtensions = *`, so Finder hands them any file. Keep it logic-free:
  it only forwards paths to the `.sh` — that way edits live-reload without a
  recompile.

`install.sh` post-processes the compiled bundle: adds a `CFBundleIdentifier`
(`osacompile` emits none, and LaunchServices can't persist an *Open With → Change
All* binding without one), sets the type role to `Editor`, then **re-signs with
`codesign --force --sign -`** — editing the plist invalidates `osacompile`'s ad-hoc
signature and macOS refuses to run the applet otherwise — and `lsregister -f`s it.
Changing the plist without re-signing is the failure mode to watch for.

`orca/set-default-apps.sh` (run by `install.sh`, needs `duti`) then makes the applet
the **default** app for `.py`, `.txt`, `.md`, `.sh`. Two traps it encodes:

- LaunchServices only binds an app to a UTI the app **declares**. The `*` wildcard
  `osacompile` emits is enough for *Open With* but **not** for default-handler
  status — `duti -s` exits 0 and changes nothing. So the script adds a second
  `CFBundleDocumentTypes` entry with an explicit `LSItemContentTypes` array
  (`LSHandlerRank = Alternate`), re-signs, `lsregister -f`s, and binds after that.
  It also `killall cfprefsd` before verifying — freshly written bindings read back
  stale otherwise, which looks like a failure that isn't one.
- **Never add `public.html` to `DEFAULT_UTIS`.** macOS equates setting the
  `public.html` handler with changing the default browser: it silently rebinds
  `http`, `https` and `com.apple.default-app.web-browser` to the same app, so every
  clicked link opens the applet. Recent macOS then refuses to change it back through
  the API (`duti` → error -54/-50); recovery meant editing
  `~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist`
  by hand and `killall cfprefsd`. The script ends with a guard that detects the
  hijack, restores Chrome, and dies. `.html` goes through right-click → *Open With*.

`watch.sh` deliberately does **not** run `set-default-apps.sh` in its initial sync —
it mutates system-wide defaults, so it only fires when that file itself is edited.

## Conventions in the configs

- tmux prefix is **`Ctrl-a`** (not the default `Ctrl-b`); copy-mode is **emacs**,
  not vi; panes split with `v` / `h`; Alt+arrows/Alt+number move without prefix.
- `.zshrc` overrides the oh-my-zsh theme prompt with a custom `PROMPT` and helper
  functions; it must stay **below** `source $ZSH/oh-my-zsh.sh`.
- `.zshrc` contains machine-specific absolute paths (JAVA_HOME, Maven, Antigravity
  under `/Users/nghiale/...`) and is not fully portable across usernames.
