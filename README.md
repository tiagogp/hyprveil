# Hyprveil — a reusable Fedora Hyprland template

Hyprveil is a dark glass-styled Hyprland desktop for the current and previous stable
Fedora releases. Its installer detects Fedora and enabled repositories, prefers
official packages, preserves persistent state, and backs up managed configuration
before clean replacement.

The visual target is `design/Hyprland Desktop Design.dc.html` (from the Claude Design
project): dark neutrals, one red accent (#E14658), heavy glass/blur surfaces,
14–16px radii, Geist for UI text, Fira Code for the terminal.

See [ROADMAP.md](ROADMAP.md) for milestone status, [docs/INSTALL.md](docs/INSTALL.md)
for repository and rerun behavior, [docs/HARDWARE.md](docs/HARDWARE.md) for profiles,
[docs/TOP-BAR-DOCK.md](docs/TOP-BAR-DOCK.md) for Bluetooth, media, and pin management,
[docs/QUICK-SETTINGS.md](docs/QUICK-SETTINGS.md) for the Wi-Fi/Bluetooth/notification panel,
[docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md) for the Quickshell default plus AGS, SwayNC, and Mako fallbacks,
[docs/TOKENS.md](docs/TOKENS.md) for the design token scale,
[docs/WALLPAPERS-MOTION.md](docs/WALLPAPERS-MOTION.md) for persistent per-monitor
wallpapers and reduced motion,
[docs/ACCENT.md](docs/ACCENT.md) for wallpaper-derived accent colors,
[docs/CONFIGURATION.md](docs/CONFIGURATION.md) for managed files, optional
dependencies, keybindings, and state locations,
[docs/RECOVERY.md](docs/RECOVERY.md) for component recovery and rollback, and
[docs/SUPPORT.md](docs/SUPPORT.md) for the rolling Fedora policy.

## How this is being delivered (step-by-step, per your preference)

**Stage 1: Hyprland core** ✅
- Centralized color palette (`hypr/colors.conf`)
- Tunable spacing/radius/animation-speed variables (`hypr/variables.conf`)
- Monitor config stub for your multi-monitor + hybrid-GPU desktop (`hypr/monitors.conf`)
- Core `hyprland.conf`, `appearance.conf`, `animations.conf`, `window-rules.conf`,
  `keybindings.conf`, `autostart.conf`
- Fedora-aware package installation plus persistent desktop/laptop and GPU profiles

**Stage 2: the desktop shell — implements the design mockup** ✅
- **Quickshell** (`quickshell/`) — the session shell in QML: the floating glass top
  bar (workspaces 1–5 left, window title center, MPRIS controls plus
  Bluetooth/network/volume/battery/clock right), an end-4-style bottom dock, the
  quick-settings panel, the notification daemon, and the lock screen — one process,
  drawn on every monitor. Pins launch installed desktop entries, including Flatpaks
  and Electron apps; right-click the launcher to add, remove, or reorder them.
  Replaced Waybar and AGS, which between them needed ten hand-duplicated dock
  modules, a `socat` event-watcher helper, and a dart-sass runtime.
- **Kitty** (`kitty/`) — translucent terminal, Fira Code, full palette mapping
- **Rofi** (`rofi/`) — 480px centered glass launcher with icon rows and accent selection
  (requires `rofi-wayland`)
- **Notifications** — served by the shell itself, with glass cards, history,
  clear-all, DND, and Bluetooth connect/disconnect and low-battery alerts. AGS,
  SwayNC (`swaync/`), and Mako remain installer-selected fallbacks.
- **Lock screen** (`quickshell/Lock/`) — oversized thin clock, accent avatar ring,
  pill password field (design "Lock" screen). **hyprlock**
  (`hypr/hyprlock.conf`) stays installed as the fallback: `hypr/scripts/lock.sh`
  drops to it whenever the shell cannot confirm it locked, because a lock screen
  that fails to appear is an unlocked machine.
- **wlogout** (`wlogout/`) — Lock/Logout/Suspend/Restart/Shutdown row, Shutdown in
  accent (design "Power" screen)
- **hyprpaper** (`hypr/hyprpaper.conf`) + **hypridle** (`hypr/hypridle.conf`),
  with a bundled offline-safe fallback wallpaper
- Keybind scheme ported from end-4/dots-hyprland (see cheatsheet below)
- `scripts/02-install-fedora-shell.sh` — packages, Geist + Nerd-symbol fonts, wallpaper

**Stage 3 (this delivery): app theming + shell environment** ✅
(screenshot + clipboard tooling originally slated here already landed in Stage 2)
- **GTK** (`gtk-3.0/`, `gtk-4.0/`) — adw-gtk3-dark for GTK3, libadwaita named-color
  overrides in `gtk.css` for both, so every GTK app gets the dark neutrals + red accent
- **Qt** (`qt5ct/`, `qt6ct/`) — Fusion style with a full hyprveil palette
  (`colors/hyprveil.conf`), Geist/Fira Code fonts, Papirus-Dark icons; Hyprland sets
  `QT_QPA_PLATFORMTHEME=qt6ct`
- **Cursor** — Bibata Modern Classic (XCURSOR + HYPRCURSOR env vars in
  `hypr/variables.conf`, installed to `~/.local/share/icons` by script 04)
- **Icons** — Papirus-Dark with folders switched to red via `papirus-folders`
- **`hypr/scripts/apply-theme.sh`** — runs at login (autostart) to push
  theme/cursor/fonts into gsettings, which is the only channel libadwaita apps read
- **zsh** (`zsh/.zshrc`) — shared history, menu completion, autosuggestions +
  syntax highlighting (Fedora packages), history search on arrow keys
- **Starship** (`starship.toml`) — minimal two-line prompt, accent-red directory
  and `❯`, git branch/status in muted gray
- `scripts/04-install-fedora-theming.sh` — packages, Bibata, papirus-folders,
  Qt config install (expands `__HOME__` placeholders), `~/.zshrc` + `chsh`

That completes the original roadmap.

**Stage 4 (extra): SDDM login-screen theming** ✅
- **SDDM** (`sddm/hyprveil/`) — QML greeter theme matching hyprlock's idiom:
  oversized thin clock, accent avatar ring + username (`userModel`-bound),
  pill password field, and a Suspend/Restart/Shutdown row styled after the
  design mockup's Power screen (reuses wlogout's installed icons so the two
  match pixel-for-pixel). Bundles its own Geist fonts since the greeter runs
  as the `sddm` system user, which can't see `~/.local/share/fonts`.
- Uses SDDM's own Wayland (Weston-backed) greeter by default — Fedora's real
  compiled-in default, not the "experimental" X11 fallback older docs
  describe — with an X11-greeter opt-out for the NVIDIA hybrid-GPU case (see
  the saved NVIDIA hardware profile; see `docs/HARDWARE.md`).
- `scripts/05-install-fedora-sddm.sh` — the one piece of hyprveil that changes
  a *system* file (`/etc/sddm.conf.d/`) and replaces the machine's display
  manager for every login, so every step inside it is separately confirmed.
  `install.sh` offers to run it as a final, separately-gated
  step; it's also runnable standalone. Test the theme with zero system
  changes first: `sddm-greeter-qt6 --test-mode --theme config/sddm/hyprveil`.

**P3 customization** ✅
- `SUPER+SHIFT+W` opens the wallpaper picker: an AGS thumbnail grid when that shell
  is running, otherwise a Rofi flow. Both choose image, connected monitor, and
  cover/contain fit; fallback and per-monitor choices restore after login.
- The helper detects current and legacy Hyprpaper IPC and recovers safely from
  missing images or malformed JSON state.
- Standard and reduced motion profiles persist outside the managed config tree,
  reload safely, and share a separate global animation toggle.

Remaining possible extras if you want them later: per-app GTK tweaks, kitty
tab/session tooling.

## Fedora packages and hardware

Do not enable a repository from a README command. The installer probes enabled DNF
repositories for each package and chooses an official Fedora source whenever one is
available. Missing Hyprland-family packages trigger an explained, explicitly
confirmed `solopasha/hyprland` COPR offer. SwayNC is likewise offered from its
upstream COPR only when unavailable officially; declining it keeps repository state
unchanged and selects the official Mako fallback. Current details live at
[Fedora Packages](https://packages.fedoraproject.org/).

The hardware selector supports desktop/laptop and Intel/AMD/NVIDIA paths. It saves
the choice under `$XDG_STATE_HOME/hyprveil`, does not change it on rerun, and enables
no GPU workaround by default. See [docs/HARDWARE.md](docs/HARDWARE.md).

## Directory structure

```
config/
├── hypr/
│   ├── hyprland.conf        # entrypoint, sources everything else
│   ├── colors.conf          # single source of truth for the palette
│   ├── variables.conf       # gaps, border width, radius, animation speed — tweak here
│   ├── monitors.conf        # your monitor layout — EDIT before first launch
│   ├── appearance.conf      # general/decoration/blur/shadow, reads colors+variables
│   ├── animations.conf      # global animation toggle + selected motion source
│   ├── window-rules.conf    # floating rules for dialogs/pickers/PiP
│   ├── keybindings.conf     # all binds
│   ├── autostart.conf       # exec-once entries
│   ├── hyprlock.conf        # lock screen (Stage 2)
│   ├── hypridle.conf        # idle -> lock -> dpms -> suspend (Stage 2)
│   ├── hyprpaper.conf       # mapping-free daemon config; state restores over IPC
│   ├── motion/              # standard/reduced profiles + generated active source
│   ├── profiles/            # persistent desktop/laptop + GPU selection targets
│   └── scripts/             # theme, zoom, and hardware-aware actions
├── quickshell/              # the session shell: bar, dock, panel, lock (QML)
├── waybar/                  # retired bar; still holds the Rofi dock pin manager
├── kitty/                   # kitty.conf (Stage 2)
├── rofi/                    # config.rasi + hyprveil.rasi theme (Stage 2)
├── swaync/                  # default notification center config + CSS
├── mako/                    # fallback notification config
├── wlogout/                 # layout + style.css (Stage 2)
├── gtk-3.0/                 # settings.ini + accent gtk.css (Stage 3)
├── gtk-4.0/                 # settings.ini + libadwaita accent gtk.css (Stage 3)
├── qt5ct/                   # qt5ct.conf + colors/hyprveil.conf (Stage 3)
├── qt6ct/                   # qt6ct.conf + colors/hyprveil.conf (Stage 3)
├── zsh/                     # .zshrc — script 04 copies it to ~/.zshrc (Stage 3)
├── starship.toml            # prompt theme (Stage 3)
└── sddm/hyprveil/           # SDDM QML greeter theme (Stage 4, extra) — a
    ├── metadata.desktop     #   *system* install (/usr/share/sddm/themes/),
    ├── theme.conf           #   not copied via ~/.config like everything else
    ├── Main.qml
    └── Components/          # Palette.qml, Clock.qml, UserAvatar.qml,
                              # PasswordField.qml, SessionPicker.qml, PowerRow.qml
design/
└── Hyprland Desktop Design.dc.html   # the mockup all of this implements
scripts/
├── 00-backup.sh
├── 01-install-fedora-core.sh
├── 02-install-fedora-shell.sh
├── 03-test-config.sh
├── 04-install-fedora-theming.sh
├── 05-install-fedora-sddm.sh   # optional, separately gated system changes
├── 06-select-profile.sh
├── 07-select-notification-backend.sh
├── 08-test-nested-session.sh   # fully isolated nested Hyprland launch
└── 09-dependency-report.sh
tests/
├── p0-smoke.sh … p4-nested-smoke.sh
└── run.sh                      # non-session P0-P4 quality gate
install.sh                      # recommended P0 entrypoint, runs the stages above
```

## Install

```bash
chmod +x scripts/*.sh
./install.sh
```

The full installer runs the individual package stages, selects or restores a
hardware profile, requires a dependency preflight before copying configs, and makes
timestamped backups. It is safe to rerun. The individual stage scripts remain
available for selective installation; see [docs/INSTALL.md](docs/INSTALL.md).

### Optional: SDDM login screen

`install.sh` above ends by offering to run this too, as its
own separately-confirmed final step. To run it standalone instead (e.g. later,
after everything else is verified working) — it's the one piece of hyprveil
that touches system files (`/usr/share/sddm/`, `/etc/sddm.conf.d/`) and can
replace your display manager:

```bash
./scripts/05-install-fedora-sddm.sh
```

It previews the theme in a window first (`sddm-greeter-qt6 --test-mode`, no
root, no system changes) before asking to install `sddm`, copy the theme,
point sddm at it, and — as a separately confirmed last step — actually enable
`sddm.service` in place of your current display manager.

## Test before use — `scripts/03-test-config.sh`

First run the deterministic non-session gate. It checks Bash syntax, uses ShellCheck
when installed, parses JSON/JSONC, checks executable bits, and runs every mocked
P0–P4 suite:

```bash
./tests/run.sh
```

Release validation uses `./tests/run.sh --require-shellcheck`, which fails instead
of warning when ShellCheck is unavailable. Then run `scripts/03-test-config.sh`
from the repo root. Phases 1 and 2 never touch real user config or state:

1. **Static checks** (run anywhere): all config files present, waybar/wlogout JSON
   valid, every command the binds call is installed, fonts installed, and — if your
   Hyprland build supports it — a full `Hyprland --verify-config` parse check.
2. **Nested live test** (when run from inside any Wayland session): boots Hyprveil
   **in a window** with `HOME` and every writable XDG directory redirected into a
   temporary stage. Config, state, cache, data, and runtime files cannot reach the
   real user directories. Exit with `SUPER+SHIFT+Q`.
3. **Install prompt**: after the nested session exits, the script offers the same
   timestamped-backup and whole-tree deployment used by the full installer. Say no
   to leave `~/.config` untouched.

The standalone nested launcher accepts `--backend swaync|mako` and `--keep-stage`:

```bash
./scripts/08-test-nested-session.sh --backend swaync
```

Manual release evidence is recorded in
[docs/VM-TEST-MATRIX.md](docs/VM-TEST-MATRIX.md); the tag gate is
[docs/RELEASE.md](docs/RELEASE.md).

**Before launching Hyprland:** open `~/.config/hypr/monitors.conf` and replace the
placeholder monitor names/resolutions with your real ones (get them via
`hyprctl monitors` after first login, or `wlr-randr` if available beforehand).

## Reload / restart

```bash
hyprctl reload                 # re-read all Hyprland configs live
qs kill; ~/.config/hypr/scripts/notification-daemon.sh start & disown  # restart the shell
swaync-client -R               # reload SwayNC config
swaync-client -rs              # reload SwayNC CSS
```

## Validation checklist

Stage 1:
- [x] `hyprctl reload` returns no errors
- [x] `hyprctl monitors` shows all displays at correct resolution/position/scale
- [x] Window open/close animation is snappy (~180ms), not sluggish
- [x] Gaps/border radius match `variables.conf` values

Stage 2 (compare against the mockup's five screens):
- [x] **Desktop**: the bar floats with rounded corners and blur; active workspace pill
      is accent-tinted; active window border is the accent, inactive `#2A2D35`
- [x] **Dock**: centered pill at the bottom; pinned icons launch apps; running apps
      appear right of the divider with a red-tinted ring on the focused one
- [x] `SUPER+Return` opens a translucent blurred Kitty with Fira Code
- [x] **Launcher**: `SUPER+Space` opens the centered 480px rofi panel; selected row
      has the red-tinted background
- [x] **Notification**: `notify-send "Build complete" "aurora compiled successfully"`
      shows a glass card top-right; `notify-send -u critical` gets the red border
- [x] **Lock**: `SUPER+L` shows big thin clock, avatar ring, pill password field
- [x] **Power**: `SUPER+Escape` shows the five-button row with Shutdown in red

Stage 3 (after script 04 + config copy + logout/login):
- [x] Cursor is Bibata (black, rounded) everywhere, including over app windows
- [x] GTK app (e.g. nautilus): dark surfaces, **red** selection/accent instead of
      blue, red folder icons, Geist as UI font
- [x] Qt app (e.g. pavucontrol if Qt, or run `qt6ct` itself): dark Fusion palette
      with red highlight — open qt6ct and check the preview
- [x] New Kitty window drops you in zsh with the Starship prompt: red directory,
      red `❯`, git branch shown inside a repo
- [x] Typing shows gray ghost autosuggestions; invalid commands render red
      (syntax highlighting)

Stage 4 (extra, after `scripts/05-install-fedora-sddm.sh`):
- [x] `sddm-greeter-qt6 --test-mode --theme config/sddm/hyprveil` shows the
      clock/avatar/password-pill matching hyprlock's look — check this
      *before* enabling sddm as the display manager
- [x] After enabling sddm + reboot: Geist renders correctly in the greeter
      (catches a stale/missing `Fonts/` bundle)
- [x] Hyprland is selectable in the session picker
- [x] Suspend/Restart/Shutdown all work, Shutdown shown in accent red

## Keybind cheatsheet (end-4 style)

Ported from end-4/dots-hyprland, minus its overview, sidebars, and on-screen
cheatsheet — those are not built here. `SUPER+Tab` maps to rofi's window switcher
instead of an overview widget. (This note predates the migration: Hyprveil now uses
Quickshell too, but has not adopted those particular surfaces.)

| Bind | Action |
|---|---|
| tap `SUPER` / `SUPER+Space` | launcher (rofi) |
| `SUPER+Tab` | window switcher |
| `SUPER+Return` / `T` | terminal |
| `SUPER+W` / `C` / `E` | browser / code editor / files |
| `CTRL+SHIFT+Escape` | btop (task manager) |
| `SUPER+V` | clipboard history |
| `SUPER+Period` | emoji picker |
| `Print` / `CTRL+Print` | screenshot → clipboard / + file |
| `SUPER+SHIFT+S` | region snip → clipboard |
| `SUPER+SHIFT+X` | region OCR → clipboard (needs tesseract) |
| `SUPER+SHIFT+C` | color picker |
| `SUPER+SHIFT+W` | wallpaper picker — Rofi list (the thumbnail grid is not yet ported to QML) |
| `SUPER+minus` / `equal` | screen zoom out / in |
| `SUPER+SHIFT+P` / `N` / `B` / `M` | media play-pause / next / prev / mute |
| `SUPER+Q` | close window (`+SHIFT+ALT` force-kill) |
| `SUPER+ALT+Space` | float/tile toggle |
| `SUPER+F` / `D` | fullscreen / maximize |
| `SUPER+P` | pin window |
| `SUPER+;` / `'` | shrink / grow split |
| `SUPER+number` (`+SHIFT` follow, `+ALT` silent) | workspaces |
| `SUPER+scroll`, `SUPER+CTRL+←/→` | cycle workspaces |
| `SUPER+S` or `SUPER+GRAVE` | scratchpad |
| `SUPER+L` / `SUPER+SHIFT+L` | lock / suspend |
| `SUPER+Escape` or `CTRL+ALT+Delete` | power menu |
| `SUPER+N` | toggle notification center |

## Customization quick guide

- **Sizes, spacing, type, motion** → edit `hypr/tokens.conf`, then run
  `~/.config/hypr/scripts/theme.sh render`. See [docs/TOKENS.md](docs/TOKENS.md).
- **Colors** → edit `hypr/colors.conf` for Hyprland; Quickshell/Kitty/Rofi/SwayNC/
  wlogout each carry a palette mirror block at the top of their file (these tools
  can't read Hyprland variables — grep for the old hex when changing a color).
  Stage 3 mirrors: `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`,
  `qt5ct/colors/hyprveil.conf`, `qt6ct/colors/hyprveil.conf`, `starship.toml`.
  Stage 4 mirror: `sddm/hyprveil/Components/Palette.qml` (also hardcoded, same
  "can't read Hyprland variables — keep in sync manually" caveat as hyprlock);
  re-run step 2 of `scripts/05-install-fedora-sddm.sh` after editing it to
  copy the change into `/usr/share/sddm/themes/hyprveil`.
- **Gaps / border width / corner radius / animation speed** → `hypr/variables.conf`.
- **Motion** → run `~/.config/hypr/scripts/motion-profile.sh standard` or
  `reduced`; set `$hyprveil_animations_enabled = false` in `hypr/animations.conf`
  to disable animation globally.
- **Blur strength** → `decoration.blur.size` / `.passes` in `appearance.conf`.
- **Monitor layout** → `hypr/monitors.conf`.
- **Idle/lock timeouts** → `hypr/hypridle.conf`.
- **Wallpaper** → put images under `~/Pictures/Wallpapers` and press
  `SUPER+SHIFT+W`, or use `hypr/scripts/wallpaper.sh apply`; see
  [docs/WALLPAPERS-MOTION.md](docs/WALLPAPERS-MOTION.md).
- **Cursor theme/size** → env vars in `hypr/variables.conf` **and**
  `hypr/scripts/apply-theme.sh` (keep both in sync), then `hyprctl reload` and
  re-run the script.
- **GTK/Qt/icon/font choices** → `hypr/scripts/apply-theme.sh` (gsettings, wins for
  libadwaita apps) plus the matching `gtk-*/settings.ini` / `qt6ct.conf`.
- **Folder accent color** → `sudo papirus-folders -C <color> --theme Papirus-Dark`.
- **Prompt** → `starship.toml` (`starship explain` helps); zsh behavior → `~/.zshrc`
  (repo copy: `config/zsh/.zshrc` — re-run the script 04 zsh step after editing).
