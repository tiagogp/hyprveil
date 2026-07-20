# Changelog

All notable changes to Hyprveil will be documented in this file.

This project follows a human-readable release log format. Each release should
identify the validated commit, supported Fedora releases, notable changes,
known limitations, and manual evidence status.

## Unreleased

### Added

- Public project foundation files: license, contribution guide, security policy,
  issue templates, pull request template, editor settings, and CI release checks.
- Maintenance commands `hyprveil update`, `hyprveil rollback`, and
  `hyprveil uninstall`, with a P9 mocked smoke-test suite covering preview,
  atomic deploy, snapshot restore, cancellation safety, and state handling.
- Re-openable `hyprveil setup` first-run flow: detects monitors and offers their
  preferred resolution/scale, and collects keyboard layout, app shortcuts, idle
  timers, wallpaper, accent, motion, hardware profile, notification backend, and
  optional SDDM. It previews before writing, has a flag for every choice, and
  saves canonical state under `$XDG_STATE_HOME/hyprveil`. Generated `local.conf`,
  `apps.conf`, and `hypridle.conf` are regenerated after every deploy via
  `setup --ensure`, so setup choices survive `hyprveil update`. Covered by a new
  P10 mocked smoke-test suite.

### Changed

- CI and local validation now name the full P0-P10 smoke-test gate.
- `hyprland.conf` now sources `apps.conf` (app shortcut variables) and, last,
  `local.conf` (machine-local monitor and keyboard overrides); the app variables
  moved out of `keybindings.conf` accordingly.
