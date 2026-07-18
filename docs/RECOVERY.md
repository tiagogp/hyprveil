# Recovery and rollback

Start with the non-session checks; they do not need a running Hyprland session and
do not modify the real user configuration:

```bash
./tests/run.sh
./scripts/03-test-config.sh
hyprctl configerrors
```

## Roll back an upgrade

Every managed replacement creates a timestamped directory below
`${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/backups`. Find the newest one:

```bash
ls -1dt "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/backups"/*
```

From a TTY or another desktop session, move the current component aside and copy
the matching backup into place. For example:

```bash
mv "$HOME/.config/hypr" "$HOME/.config/hypr.failed"
cp -a /path/to/backup/config/hypr "$HOME/.config/hypr"
```

Restore only the affected component where possible. Persistent pins, wallpaper
mappings, motion choice, and notification selection are outside the managed config
backup and normally should not be rolled back. If a state migration is the problem,
move that one state file aside first; its helper will preserve/rebuild it.

## Broken Hyprland configuration

Switch to a TTY, restore the backed-up `hypr` tree as above, and validate before
logging back in:

```bash
Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.conf"
```

If that Hyprland build lacks `--verify-config`, use
`./scripts/08-test-nested-session.sh` from another Wayland desktop. The nested
launcher isolates config and all writable XDG state.

## Broken Waybar

Run Waybar in the foreground to retain its error output:

```bash
pkill waybar
waybar -l debug
```

Validate `config/waybar/config.jsonc` with `./tests/run.sh`. Restore the backed-up
`waybar` tree if needed, then start `waybar`. Dock pins live in
`dock-pins.json`; run `~/.config/waybar/scripts/dock-manager.sh list` to validate
and safely recover only that state.

## Broken wallpaper daemon

Restart Hyprpaper and replay valid saved mappings:

```bash
pkill hyprpaper
hyprpaper &
~/.config/hypr/scripts/wallpaper.sh restore
```

If state is malformed, the restore command preserves it with an `.invalid-*`
suffix and creates safe fallback state. If the daemon config itself is broken,
restore the backed-up `hypr/hyprpaper.conf` or the full `hypr` tree.

## Broken notification daemon

Inspect the selection and make sure its command is installed:

```bash
cat "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/notification-backend"
~/.config/hypr/scripts/notification-daemon.sh backend
~/.config/hypr/scripts/notification-daemon.sh restart
```

Reselect with `scripts/07-select-notification-backend.sh --backend swaync` or
`--backend mako`, redeploy, and restart Waybar. The helper stops the inactive daemon
so two notification daemons cannot compete for the D-Bus service.

## Reset motion safely

```bash
mv "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/motion-profile" \
   "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/motion-profile.manual-backup"
~/.config/hypr/scripts/motion-profile.sh --ensure
```

The safe default is `standard`. A live profile switch that Hyprland rejects is
rolled back automatically.
