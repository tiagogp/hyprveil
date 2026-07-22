# Hyprveil

[![quality](https://github.com/tiagogp/hyprveil/actions/workflows/quality.yml/badge.svg)](https://github.com/tiagogp/hyprveil/actions/workflows/quality.yml)

Hyprveil is a reusable Fedora Hyprland desktop template with a dark glass visual
system, a Quickshell-based shell, wallpaper-aware accents, persistent hardware
profiles, and a cautious installer that backs up managed configuration before
replacing it.

The default desktop is Quickshell QML: it draws the floating top bar, bottom dock,
Quick Settings, notification popups/history, wallpaper picker, keybind cheatsheet,
and lock screen. Waybar remains in the repository as a legacy/fallback bar, while
SwayNC and Mako are notification-only fallbacks for systems that do not run the
Quickshell notification backend.

## Screenshots

| | |
|---|---|
| ![Desktop: bar and dock](docs/images/desktop.png) Desktop — bar, dock, accent-tinted focus | ![Launcher](docs/images/launcher.png) Launcher — rofi, centered, accent selection |
| ![Lock screen](docs/images/lock.png) Lock screen — clock, avatar ring, pill password field | ![Notification](docs/images/notification.png) Notification — glass card, critical red border |
| ![Power menu](docs/images/power-menu.png) Power menu — five-button row, red shutdown | |

*(Images pending — see [CONTRIBUTING.md](CONTRIBUTING.md#screenshots) for the
capture convention if you'd like to contribute a set.)*

## Requirements

- Fedora 44 or Fedora 43. Other Fedora versions may work, but they are outside
  the release-tested support window in `support/fedora-releases.conf`.
  Hyprveil targets one distribution and one compositor on purpose: the
  installer probes real DNF/COPR package sources and the config assumes
  Hyprland, and supporting more of either would mean testing configurations
  no one commits to a smoke test. Porting the config by hand to another
  distro or compositor is reasonable; the installer will not attempt it for
  you.
- A Wayland-capable system that can run Hyprland.
- `dnf`, Bash, and a user account allowed to install packages with `sudo`.
- Network access during package installation, unless all required packages are
  already installed from enabled repositories.

## Install

```bash
chmod +x scripts/*.sh
./install.sh
```

The installer probes enabled Fedora repositories first, offers COPR fallbacks only
when needed, records package-source choices, preserves state under
`$XDG_STATE_HOME/hyprveil`, and creates timestamped backups before replacing
Hyprveil-managed config trees. It is safe to rerun.

Important warnings:

- Run `./hyprveil setup` after installing to detect monitors and pick keyboard,
  apps, and idle timers. For common single-monitor hardware the shipped catch-all
  layout already works; `setup` is what handles multi-monitor and custom scale
  without hand-editing `~/.config/hypr/monitors.conf`.
- Hyprveil replaces only its managed configuration trees, but you should still
  read [docs/INSTALL.md](docs/INSTALL.md) and [docs/RECOVERY.md](docs/RECOVERY.md)
  before installing on a daily-driver machine.

## Features

- Hyprland configuration split into focused files for monitors, appearance,
  animations, window rules, keybindings, autostart, idle, lock, and hardware
  profiles.
- Quickshell shell with a glass top bar, workspace controls, focused-window title,
  MPRIS media controls, status cluster, dock, Quick Settings, notifications,
  wallpaper picker, cheatsheet, and lock screen.
- Backend-aware notification launcher with Quickshell as the default and SwayNC or
  Mako as selected fallbacks.
- Wallpaper state and per-monitor fit restored through Hyprpaper IPC.
- Standard/reduced motion profiles and a global animation toggle.
- Wallpaper-derived accent rendering for Hyprland, Quickshell, Kitty, Rofi,
  wlogout, GTK, Qt, SwayNC, and Mako templates, plus a handful of curated
  accent presets for picking a look without a wallpaper (`accent.sh preset`).
- GTK 3/4, Qt 5/6, Kitty, Rofi, wlogout, Papirus, Bibata, Geist, Fira Code, and
  Starship theming.
- Mocked non-session smoke tests for installer safety, shell wiring, accents,
  tokens, lock fallback behavior, and nested-session setup.

## Documentation

The docs are intentionally small:

- [docs/INSTALL.md](docs/INSTALL.md): installer behavior, reruns, and backups.
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md): managed files, state, tokens,
  accents, keybindings, and optional dependencies.
- [docs/HARDWARE.md](docs/HARDWARE.md): desktop/laptop and GPU profiles.
- [docs/QUICK-SETTINGS.md](docs/QUICK-SETTINGS.md): panel controls and cheatsheet.
- [docs/RECOVERY.md](docs/RECOVERY.md): rollback and component recovery.

Licensing lives in [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the test gate, the
edit-source-then-render rule generated files follow, and how to add an
accent preset, keybinding, or screenshot.

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
│   ├── neutrals.conf        # single source of truth for the neutral palette
│   ├── colors.conf          # sources neutrals.conf + the accent design defaults
│   ├── tokens.conf          # shared size, radius, alpha, font, and timing tokens
│   ├── variables.conf       # gaps, border width, radius, animation speed - tweak here
│   ├── monitors.conf        # catch-all monitor default; `hyprveil setup` overrides it
│   ├── appearance.conf      # general/decoration/blur/shadow, reads colors+variables
│   ├── animations.conf      # global animation toggle + selected motion source
│   ├── window-rules.conf    # floating rules for dialogs/pickers/PiP
│   ├── apps.conf            # app shortcut vars; generated by `hyprveil setup`
│   ├── keybindings.conf     # all binds
│   ├── autostart.conf       # exec-once entries
│   ├── local.conf           # monitor/keyboard overrides; generated by `hyprveil setup`, sourced last
│   ├── hyprlock.conf        # lock fallback
│   ├── hypridle.conf        # idle -> lock -> dpms -> suspend; timers set by `hyprveil setup`
│   ├── hyprpaper.conf       # mapping-free daemon config; state restores over IPC
│   ├── motion/              # standard/reduced profiles + generated active source
│   ├── profiles/            # persistent desktop/laptop + GPU selection targets
│   └── scripts/             # theme, zoom, and hardware-aware actions
├── quickshell/              # the session shell: bar, dock, panel, lock (QML)
├── waybar/                  # legacy bar and helper scripts
├── kitty/                   # terminal theme and optional tab/session helper
├── rofi/                    # launcher and accent selector theme
├── swaync/                  # notification fallback config and CSS
├── mako/                    # minimal notification fallback config
├── wlogout/                 # power menu layout, CSS, and icons
├── gtk-3.0/                 # GTK3 settings and accent CSS
├── gtk-4.0/                 # GTK4/libadwaita accent CSS
├── qt5ct/                   # Qt5 palette
├── qt6ct/                   # Qt6 palette
├── fontconfig/              # font fallback rules
├── starship.toml            # prompt theme (generated from starship.toml.in)
└── starship.toml.in         # prompt template; accent.sh render fills the palette
scripts/
├── 00-backup.sh
├── 01-install-fedora-core.sh
├── 02-install-fedora-shell.sh
├── 03-test-config.sh
├── 04-install-fedora-theming.sh
├── 06-select-profile.sh
├── 07-select-notification-backend.sh
├── 08-test-nested-session.sh   # fully isolated nested Hyprland launch
├── 09-dependency-report.sh
├── 10-first-run-setup.sh       # guided or flag-driven local setup
├── uninstall.sh                 # remove Hyprveil while keeping Kitty and zsh
└── lib/                       # shared installer and render helpers
tests/
├── p0-smoke.sh ... p10-setup-smoke.sh
└── run.sh                      # non-session P0-P10 quality gate
install.sh                      # recommended entrypoint
hyprveil                        # maintenance command (doctor/update/rollback/uninstall)
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

Hyprveil no longer ships a login screen (display manager). It touches only your
user configuration under `~/.config`; keep whatever display manager your system
already uses, or launch Hyprland from a TTY.

## Test before use — `scripts/03-test-config.sh`

First run the deterministic non-session gate. It checks Bash syntax, uses ShellCheck
when installed, parses JSON/JSONC, checks executable bits, and runs every mocked
P0-P10 suite:

```bash
./tests/run.sh
```

Use `./tests/run.sh --require-shellcheck` when ShellCheck must be enforced instead
of treated as optional. Then run `scripts/03-test-config.sh`
from the repo root. Phases 1 and 2 never touch real user config or state:

1. **Static checks** (run anywhere): all config files present, legacy Waybar/wlogout JSON
   valid, every command the binds call is installed, fonts installed, and — if your
   Hyprland build supports it — a full `Hyprland --verify-config` parse check.
2. **Nested live test** (when run from inside any Wayland session): boots Hyprveil
   **in a window** with `HOME` and every writable XDG directory redirected into a
   temporary stage. Config, state, cache, data, and runtime files cannot reach the
   real user directories. Exit with `SUPER+SHIFT+Q`.
3. **Install prompt**: after the nested session exits, the script offers the same
   timestamped-backup and whole-tree deployment used by the full installer. Say no
   to leave `~/.config` untouched.

The standalone nested launcher accepts `--backend quickshell|swaync|mako` and `--keep-stage`:

```bash
./scripts/08-test-nested-session.sh --backend quickshell
```

### Uninstall

To remove Hyprveil-managed config while keeping Kitty and zsh:

```bash
./scripts/uninstall.sh
```

Add `--packages` if you also want it to offer removal of recorded DNF packages.
The script still keeps `kitty`, `zsh`, `~/.config/kitty`, and `~/.zshrc`.

### First-run setup

After installing, run the guided setup to configure the machine:

```bash
./hyprveil setup            # interactive; --preview to dry-run, --yes to accept defaults
```

It detects monitors and offers their preferred resolution/scale, then collects
keyboard layout, app shortcuts, idle timers, wallpaper, accent, and motion. It
previews everything before writing and is safe to re-run. Every choice has a flag
(`./scripts/10-first-run-setup.sh --help`), so it also runs unattended.

### Maintenance doctor

Run a read-only support report without changing configuration or state:

```bash
./hyprveil doctor
```

The doctor reports Fedora support, repository source shape, dependency presence,
Hyprland and Quickshell health, selected backend/profile state, wallpaper/accent
state, dock pins, and managed-tree deployment.

## Reload / restart

```bash
hyprctl reload
~/.config/hypr/scripts/notification-daemon.sh restart
~/.config/hypr/scripts/wallpaper.sh restore
~/.config/hypr/scripts/apply-theme.sh
```

The notification helper restarts the selected backend only: Quickshell by default,
or SwayNC/Mako when one of those fallbacks is selected.

## Validation checklist

Hyprland core:
- [x] `hyprctl reload` returns no errors
- [x] `hyprctl monitors` shows all displays at correct resolution/position/scale
- [x] Window open/close animation is snappy (~200ms in / ~100ms out), not sluggish
- [x] Gaps/border radius match `variables.conf` values

Shell and desktop surfaces:
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

Application theming:
- [x] Cursor is Bibata (black, rounded) everywhere, including over app windows
- [x] GTK app (e.g. nautilus): dark surfaces, **red** selection/accent instead of
      blue, red folder icons, Geist as UI font
- [x] Qt app (e.g. pavucontrol if Qt, or run `qt6ct` itself): dark Fusion palette
      with red highlight — open qt6ct and check the preview
- [x] New Kitty window drops you in zsh with the Starship prompt: red directory,
      red `❯`, git branch shown inside a repo
- [x] Typing shows gray ghost autosuggestions; invalid commands render red
      (syntax highlighting)

## Keybind cheatsheet (end-4 style)

Ported from end-4/dots-hyprland, minus its overview and sidebars — those are not
built here. `SUPER+Tab` maps to rofi's window switcher instead of an overview
widget.

The table below is a summary. `SUPER+/` opens the **on-screen cheatsheet**, which
is generated from `config/hypr/keybindings.conf` itself and so lists every bind,
including any you add — see [Cheatsheet](docs/QUICK-SETTINGS.md#keybind-cheatsheet).

| Bind | Action |
|---|---|
| `SUPER+slash` | keybind cheatsheet (every bind, read from the config) |
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
| `SUPER+SHIFT+W` | wallpaper picker — thumbnail grid, or Rofi when no shell is running |
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
  `~/.config/hypr/scripts/theme.sh render`.
- **Colors** → edit the **neutral** palette (`$bg`, `$text`, `$text-muted`,
  `$warning`, …) in `hypr/neutrals.conf`, the single source of truth every
  consumer reads; edit the **accent** with `hypr/scripts/accent.sh set #rrggbb`
  (or let the wallpaper drive it), or pick one of the curated presets with
  `hypr/scripts/accent.sh preset list` and `accent.sh preset <name>`. Then run
  `~/.config/hypr/scripts/accent.sh render`. Every tool that can't read a
  Hyprland variable — Quickshell, Kitty, Rofi, SwayNC, wlogout, GTK, Qt,
  starship, and hyprlock — is **generated** from those two sources, so there is
  no longer a per-tool mirror to keep in sync by hand (`accent.sh check` fails
  the test gate if one drifts).
- **Gaps / border width / corner radius / animation speed** → `hypr/variables.conf`.
- **Motion** → run `~/.config/hypr/scripts/motion-profile.sh standard` or
  `reduced`; set `$hyprveil_animations_enabled = false` in `hypr/animations.conf`
  to disable animation globally.
- **Blur strength** → `decoration.blur.size` / `.passes` in `appearance.conf`.
- **Monitor layout** → `./hyprveil setup` (writes `hypr/local.conf`), or edit
  `hypr/monitors.conf` for the catch-all default.
- **App shortcuts** (terminal/browser/files/editor) → `./hyprveil setup`
  (writes `hypr/apps.conf`).
- **Idle/lock timeouts** → `./hyprveil setup --idle-lock/--idle-dpms/--idle-suspend`
  (writes `hypr/hypridle.conf`).
- **Wallpaper** → put images under `~/Pictures/Wallpapers` and press
  `SUPER+SHIFT+W`, or use `hypr/scripts/wallpaper.sh apply`.
- **Cursor theme/size** → env vars in `hypr/variables.conf` **and**
  `hypr/scripts/apply-theme.sh` (keep both in sync), then `hyprctl reload` and
  re-run the script.
- **GTK/Qt/icon/font choices** → `hypr/scripts/apply-theme.sh` (gsettings, wins for
  libadwaita apps) plus the matching `gtk-*/settings.ini` / `qt6ct.conf`.
- **Folder accent color** → `sudo papirus-folders -C <color> --theme Papirus-Dark`.
- **Prompt** → edit `starship.toml.in` (the generated `starship.toml` is rewritten
  by `accent.sh render`), then render; `starship explain` helps.
