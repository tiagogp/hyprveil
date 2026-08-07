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

## Validation checklist

After installing and running `./hyprveil setup`, confirm the theme applied correctly:

Shell:
- [x] **Bar**: is accent-tinted; active window border is the accent, inactive `#2A2D35`
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

(Substitute your own accent color where "red" appears above if you changed the
default — see [CONFIGURATION.md](CONFIGURATION.md) for accent presets.)

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
or `./tests/run.sh` for Bash/JSON/executable validation and the focused non-root
checks. Use `./tests/run.sh --require-shellcheck` when ShellCheck should be
enforced instead of treated as optional. See [RECOVERY.md](RECOVERY.md) for
component recovery and full rollback.
