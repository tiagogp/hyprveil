# Hyprveil

Hyprveil is a reusable Fedora Hyprland desktop template with a dark glass visual
system, a Quickshell-based shell, wallpaper-aware accents, persistent hardware
profiles, and a cautious installer that backs up managed configuration before
replacing it.

The default desktop is Quickshell QML: it draws the floating top bar, bottom dock,
Quick Settings, notification popups/history, wallpaper picker, keybind cheatsheet,
and lock screen. Waybar remains in the repository as a legacy/fallback bar, while
SwayNC and Mako are notification-only fallbacks for systems that do not run the
Quickshell notification backend.

## Requirements

- Fedora 44 or Fedora 43. Other Fedora versions may work, but they are outside
  the release-tested support window in `support/fedora-releases.conf`.
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

- Review `~/.config/hypr/monitors.conf` before relying on a first real session;
  the current template still ships a monitor stub.
- The optional SDDM installer changes system login configuration and is always
  separately confirmed.
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
  wlogout, GTK, Qt, SwayNC, and Mako templates.
- GTK 3/4, Qt 5/6, Kitty, Rofi, wlogout, Papirus, Bibata, Geist, Fira Code, and
  Starship theming.
- Optional SDDM greeter theme with a rendered backdrop derived from the current
  wallpaper.
- Mocked non-session smoke tests for installer safety, shell wiring, accents,
  tokens, lock fallback behavior, and nested-session setup.

## Documentation

See [docs/INSTALL.md](docs/INSTALL.md) for repository and rerun behavior,
[docs/HARDWARE.md](docs/HARDWARE.md) for profiles,
[docs/TOP-BAR-DOCK.md](docs/TOP-BAR-DOCK.md) for Bluetooth, media, and pin management,
[docs/QUICK-SETTINGS.md](docs/QUICK-SETTINGS.md) for the Wi-Fi/Bluetooth/notification panel,
[docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md) for the Quickshell default plus SwayNC and Mako fallbacks,
[docs/TOKENS.md](docs/TOKENS.md) for the design token scale,
[docs/WALLPAPERS-MOTION.md](docs/WALLPAPERS-MOTION.md) for persistent per-monitor wallpapers and reduced motion,
[docs/ACCENT.md](docs/ACCENT.md) for wallpaper-derived accent colors,
[docs/CONFIGURATION.md](docs/CONFIGURATION.md) for managed files, optional dependencies, keybindings, and state locations,
[docs/MAINTENANCE.md](docs/MAINTENANCE.md) for the read-only doctor command,
[docs/RECOVERY.md](docs/RECOVERY.md) for component recovery and rollback,
[docs/SUPPORT.md](docs/SUPPORT.md) for the rolling Fedora policy, and
[ROADMAP.md](ROADMAP.md) for milestone history.

Project process lives in [CONTRIBUTING.md](CONTRIBUTING.md), release notes in
[CHANGELOG.md](CHANGELOG.md), security reporting in [SECURITY.md](SECURITY.md),
and licensing in [LICENSE](LICENSE).

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
│   ├── tokens.conf          # shared size, radius, alpha, font, and timing tokens
│   ├── variables.conf       # gaps, border width, radius, animation speed - tweak here
│   ├── monitors.conf        # monitor layout - edit before first launch
│   ├── appearance.conf      # general/decoration/blur/shadow, reads colors+variables
│   ├── animations.conf      # global animation toggle + selected motion source
│   ├── window-rules.conf    # floating rules for dialogs/pickers/PiP
│   ├── keybindings.conf     # all binds
│   ├── autostart.conf       # exec-once entries
│   ├── hyprlock.conf        # lock fallback
│   ├── hypridle.conf        # idle -> lock -> dpms -> suspend
│   ├── hyprpaper.conf       # mapping-free daemon config; state restores over IPC
│   ├── motion/              # standard/reduced profiles + generated active source
│   ├── profiles/            # persistent desktop/laptop + GPU selection targets
│   └── scripts/             # theme, zoom, and hardware-aware actions
├── quickshell/              # the session shell: bar, dock, panel, lock (QML)
├── waybar/                  # legacy bar and helper scripts
├── kitty/                   # terminal theme
├── rofi/                    # launcher and accent selector theme
├── swaync/                  # notification fallback config and CSS
├── mako/                    # minimal notification fallback config
├── wlogout/                 # power menu layout, CSS, and icons
├── gtk-3.0/                 # GTK3 settings and accent CSS
├── gtk-4.0/                 # GTK4/libadwaita accent CSS
├── qt5ct/                   # Qt5 palette
├── qt6ct/                   # Qt6 palette
├── fontconfig/              # font fallback rules
├── starship.toml            # prompt theme
└── sddm/hyprveil/           # optional SDDM QML greeter theme
    ├── metadata.desktop     #   *system* install (/usr/share/sddm/themes/),
    ├── theme.conf           #   not copied via ~/.config like everything else
    ├── Main.qml
    └── Components/          # Palette.qml, Clock.qml, UserAvatar.qml,
                              # PasswordField.qml, SessionPicker.qml, PowerRow.qml
design/
└── Custom Hyprland Desktop Environment/   # source design export and assets
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
├── p0-smoke.sh ... p8-lock-smoke.sh
└── run.sh                      # non-session P0-P8 quality gate
install.sh                      # recommended entrypoint
hyprveil                        # read-only maintenance command
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
P0-P8 suite:

```bash
./tests/run.sh
```

Release validation uses `./tests/run.sh --require-shellcheck`, which fails instead
of warning when ShellCheck is unavailable. Then run `scripts/03-test-config.sh`
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

Manual release evidence is recorded in
[docs/VM-TEST-MATRIX.md](docs/VM-TEST-MATRIX.md); the tag gate is
[docs/RELEASE.md](docs/RELEASE.md).

### Maintenance doctor

Run a read-only support report without changing configuration or state:

```bash
./hyprveil doctor
```

The doctor reports Fedora support, repository source shape, dependency presence,
Hyprland and Quickshell health, selected backend/profile state, wallpaper/accent
state, dock pins, and managed-tree deployment. See
[docs/MAINTENANCE.md](docs/MAINTENANCE.md).

**Before launching Hyprland:** open `~/.config/hypr/monitors.conf` and replace the
placeholder monitor names/resolutions with your real ones (get them via
`hyprctl monitors` after first login, or `wlr-randr` if available beforehand).

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
- [x] Window open/close animation is snappy (~180ms), not sluggish
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

Optional SDDM greeter:
- [x] `sddm-greeter-qt6 --test-mode --theme config/sddm/hyprveil` shows the
      clock/avatar/password-pill matching hyprlock's look — check this
      *before* enabling sddm as the display manager
- [x] After enabling sddm + reboot: Geist renders correctly in the greeter
      (catches a stale/missing `Fonts/` bundle)
- [x] Hyprland is selectable in the session picker
- [x] Suspend/Restart/Shutdown all work, Shutdown shown in accent red

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
  `~/.config/hypr/scripts/theme.sh render`. See [docs/TOKENS.md](docs/TOKENS.md).
- **Colors** → edit `hypr/colors.conf` for Hyprland; Quickshell/Kitty/Rofi/SwayNC/
  wlogout each carry a palette mirror block at the top of their file (these tools
  can't read Hyprland variables — grep for the old hex when changing a color).
  Application theme mirrors: `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`,
  `qt5ct/colors/hyprveil.conf`, `qt6ct/colors/hyprveil.conf`, `starship.toml`.
  SDDM mirror: `sddm/hyprveil/Components/Palette.qml` (also hardcoded, same
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
- **Prompt** → `starship.toml` (`starship explain` helps).
