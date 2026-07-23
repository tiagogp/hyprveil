# Installation, reruns, and recovery

Run the full installer on Fedora:

```bash
./install.sh
```

The installer reads `/etc/os-release`, reports whether the release is in the rolling
support pair, and probes currently enabled DNF repositories with `repoquery`. It
records package selections in `$XDG_STATE_HOME/hyprveil/package-sources.tsv`.

For every package group, official Fedora repositories are selected first. If a
required Hyprland-family package is absent, the installer explains the affected
feature and offers `solopasha/hyprland`; it never enables that COPR without an
explicit yes. SwayNC is similarly offered from `erikreider/SwayNotificationCenter`
only after official repositories are probed. Refusing that COPR leaves repositories
unchanged and installs Fedora's Mako package as the notification fallback.
Optional packages without a source are reported with only their affected shortcut
or feature disabled.
Current package details should be checked through [Fedora Packages](https://packages.fedoraproject.org/),
not inferred from a Fedora version number.

Before config deployment, `scripts/09-dependency-report.sh --preflight` lists
required, optional, installed, available, and unavailable dependencies. A missing
required dependency blocks the copy; missing optional dependencies do not.

## Safe reruns

Hyprveil owns these targets: `hypr`, `quickshell`, `waybar`, `kitty`, `rofi`,
`wlogout`, `gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct`, `fontconfig`, and
`starship.toml`. Existing targets are copied to a unique, timestamped directory
below `$XDG_STATE_HOME/hyprveil/backups`, then replaced as a whole. Whole-tree
replacement prevents removed template files from accumulating.
It also owns exactly one notification fallback tree, `swaync` or `mako`, according
to the persisted backend; switching backs up and removes the inactive managed tree.
Quickshell is deployed regardless because it owns the shell UI even when
notifications are served by a fallback daemon.

Legacy `wallpaper.jpg` files are carried forward, and the bundled fallback is
refreshed during deployment. Wallpaper mappings, motion choice, dock pins, and
installer choices live under `$XDG_STATE_HOME/hyprveil` and are never removed.
The installer regenerates the active motion source from the saved choice after a
clean config replacement. Qt, cursor, and shell steps likewise back up an
existing target before replacement.

Select a backend explicitly with:

```bash
./scripts/07-select-notification-backend.sh --backend quickshell
./scripts/07-select-notification-backend.sh --backend swaync
./scripts/07-select-notification-backend.sh --backend mako
```

Redeploy configs after switching. Startup, Quickshell, and the legacy Waybar bridge
read the same state file, so only the selected daemon starts and all notification
actions follow that backend.

## Uninstall

Use the standalone helper when you want Hyprveil removed but want to keep your
terminal and shell setup:

```bash
./scripts/uninstall.sh
```

It backs up and removes Hyprveil-managed config, Qt theme config, and optional
user-local assets, but preserves `~/.config/kitty`, `~/.zshrc`, and the `kitty`
and `zsh` packages. Pass `--packages` to offer removal of recorded DNF packages
other than Kitty and zsh.

## Recovery

List backups newest first:

```bash
ls -1dt "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/backups"/*
```

Restore one managed config after moving the current copy aside:

```bash
cp -a /path/to/backup/config/waybar "$HOME/.config/waybar"
```

Then reload Hyprland or restart the affected component. The installer never deletes
backup directories automatically.

Run `./scripts/03-test-config.sh` for config validation and Fedora/source reporting,
or `./tests/run.sh` for Bash/JSON/executable validation and every non-root mocked
behavior check. Use `./tests/run.sh --require-shellcheck` when ShellCheck should be
enforced instead of treated as optional. See [RECOVERY.md](RECOVERY.md) for
component recovery and full rollback.
