# Hyprveil

[![quality](https://github.com/tiagogp/hyprveil/actions/workflows/quality.yml/badge.svg)](https://github.com/tiagogp/hyprveil/actions/workflows/quality.yml)

Hyprveil is a reusable Fedora Hyprland desktop template with a dark glass visual
system, a Quickshell-based shell, wallpaper-aware accents, persistent hardware
profiles, and a cautious installer that backs up managed configuration before
replacing it.

The default desktop is Quickshell QML: it draws the floating top bar, bottom dock,
Quick Settings, notification popups/history, wallpaper picker, keybind cheatsheet,
and lock screen. The explicit `recovery` profile starts Waybar with Rofi,
wlogout, and SwayNC or Mako; those tools are not presented as parallel parts of
the default product.

## Screenshots

| | |
|---|---|
| ![Desktop: bar and dock](docs/images/desktop.png) Desktop — unified bar, dock, and wallpaper-derived accent | ![Desktop with blue accent](docs/images/desktop-accent.png) The same shell with a wallpaper-derived blue accent |
| ![Wallpaper picker](docs/images/wallpaper-picker.png) Wallpaper picker — per-monitor fit, live accent preview | ![Keybind cheatsheet](docs/images/cheatsheet.png) Keybind cheatsheet — searchable, grouped by category |

The old Rofi launcher capture is no longer shown as the product launcher. Run
`tests/capture-shell.sh` from a live Hyprland session to refresh the complete
release set and `shell-demo.webm` after a visual change.

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
Hyprveil-managed config trees. It also installs the versioned CLI under
`~/.local/bin/hyprveil` and Bash completion under `$XDG_DATA_HOME`. It is safe
to rerun.

Important warnings:

- Run `hyprveil setup` after installing to detect monitors and pick keyboard,
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
- Exclusive surface coordination for the native launcher, session dialog, Quick
  Settings, preferences, wallpaper picker, overview, calendar, and cheatsheet.
- Explicit default/recovery profiles; the doctor labels recovery as degraded.
- Versioned `$XDG_CONFIG_HOME/hyprveil/shell.json` schema v2 with one shared
  defaults source, validation, v1 migration, atomic writes,
  corrupt-file recovery, providers, accessibility, and per-monitor overrides.
- Installed, versioned `hyprveil shell` and `hyprveil wallpaper` commands with
  Bash completion.
- Wallpaper state and per-monitor fit restored through Hyprpaper IPC.
- Standard/reduced motion profiles and a global animation toggle.
- Wallpaper-derived accent rendering for Hyprland, Quickshell, Kitty, Rofi,
  wlogout, GTK, Qt, SwayNC, and Mako templates, plus a handful of curated
  accent presets for picking a look without a wallpaper (`accent.sh preset`).
- GTK 3/4, Qt 5/6, Kitty, Rofi, wlogout, Papirus, Bibata, Geist, Fira Code, and
  Starship theming.
- Lightweight non-session quality gate plus an explicit self-hosted Wayland
  runtime gate for real QML loading, IPC latency, CPU, and memory measurements.

## Documentation

The docs are intentionally small:

- [docs/TEMPLATE.md](docs/TEMPLATE.md): what to edit after cloning, generated
  files, state, and safe customization flow.
- [docs/INSTALL.md](docs/INSTALL.md): installer behavior, reruns, and backups.
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md): managed files, state, tokens,
  accents, keybindings, and optional dependencies.
- [docs/HARDWARE.md](docs/HARDWARE.md): desktop/laptop and GPU profiles.
- [docs/QUICK-SETTINGS.md](docs/QUICK-SETTINGS.md): panel controls and cheatsheet.
- [docs/SHELL-ARCHITECTURE.md](docs/SHELL-ARCHITECTURE.md): runtime layers,
  surface ownership, service contracts, and behavioral invariants.
- [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md): reusable controls, density,
  type, elevation, focus, accessibility, and motion.
- [docs/QUICKSHELL-COMPETITIVE-ANALYSIS.md](docs/QUICKSHELL-COMPETITIVE-ANALYSIS.md):
  competitive benchmark and roadmap against leading Hyprland + Quickshell shells.
- [docs/RECOVERY.md](docs/RECOVERY.md): rollback and component recovery.

Notable changes are tracked in [CHANGELOG.md](CHANGELOG.md); see
[docs/TEMPLATE.md](docs/TEMPLATE.md#versioning-and-updates) for how a
customized fork pulls those changes in. Licensing lives in [LICENSE](LICENSE).

## Test before use

Run the deterministic non-session gate from the repo root:

```bash
./tests/run.sh
```

It checks Bash syntax, ShellCheck when available, JSON/JSONC parsing, executable
bits, Markdown links, a few focused smoke tests, and benchmark metadata. Use
`./tests/run.sh --require-shellcheck` when ShellCheck should be enforced instead
of treated as optional.

For a deeper local validation, run:

```bash
./scripts/03-test-config.sh
```

That script adds config presence checks, optional Hyprland config parsing when
supported, and an isolated nested-session test when run from another Wayland
session.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the test gate, the
edit-source-then-render rule generated files follow, and how to add an
accent preset, keybinding, or screenshot.
