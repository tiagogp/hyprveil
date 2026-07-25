# Changelog

All notable changes to Hyprveil are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and once tagged
releases begin, version numbers follow [Semantic Versioning](https://semver.org/).

Until the first tagged release, everything lives under `[Unreleased]`. See
[docs/TEMPLATE.md](docs/TEMPLATE.md#versioning-and-updates) for how forks and
clones pull these changes in.

## [Unreleased]

### Security

- `scripts/04-install-fedora-theming.sh` pins the papirus-folders and
  pokemon-colorscripts installers to reviewed commits instead of fetching
  whatever their default branch currently is, and verifies papirus-folders
  against a checksum before it runs with `sudo`.

### Fixed

- `config/hypr/scripts/lib/render-lib.sh`'s `write_if_changed()` no longer
  reports success when the write itself fails (e.g. permission denied, disk
  full); it now aborts the render loudly instead of silently leaving a
  consumer stale.
- `config/hypr/appearance.conf` no longer sets the inert `dim_strength`
  (it had no effect without `dim_inactive = true`).

### Added

- `xdg-desktop-portal-gtk` is now a required dependency and installed in
  `scripts/01-install-fedora-core.sh`'s core stage — without it, GTK file-picker
  dialogs have no portal backend to render through.
- `hyprveil setup`'s idle timers now default to a shorter lock/dpms/suspend
  cadence (300/480/900s) when a battery is detected, instead of always using
  the desktop defaults (600/900/1800s). Any saved or explicitly-passed value
  still takes priority.
- `config/hypr/profiles/form-factor/laptop.conf` documents lid-close
  behavior: systemd-logind and hypridle already handle the common case, with
  an opt-in compositor-level bind for clamshell/docked setups.
- `CODE_OF_CONDUCT.md` and `.github/PULL_REQUEST_TEMPLATE.md`.
