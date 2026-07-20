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

## Broken shell (no bar, no dock, no notifications)

The bar, dock, quick-settings panel, notification daemon, and lock screen are one
Quickshell process, so all of them failing together is one fault, not five.

Run it in the foreground to see why:

```bash
qs kill
quickshell            # QML errors print with the file and line that failed
```

A QML load error names the chain that failed, innermost last. The two failures
worth recognising:

- **`Type X unavailable` / `X is not a type`** — a missing `qmldir` entry. Adding a
  `qmldir` *replaces* implicit same-directory resolution, so every component in
  that directory has to be listed, not just the singletons.
- **The shell loads but looks wrong — flat corners, tiny text.** A `pragma
  Singleton` with no `qmldir` entry resolves to the uninstantiated type, so
  `Tokens.radiusMd` reads as `undefined` and renders as `0` with no error at all.

Restore the backed-up `quickshell` tree if needed. Dock pins live in
`dock-pins.json`; run `~/.config/waybar/scripts/dock-manager.sh list` to validate
and safely recover only that state. (That script still lives under the retired
`waybar` tree — it backs the Rofi pin manager, which was kept.)

To fall back to the previous shell without reinstalling:

```bash
./scripts/07-select-notification-backend.sh --backend ags
~/.config/hypr/scripts/notification-daemon.sh restart
waybar & disown
```

## Locked out, or the lock screen misbehaves

`hypr/scripts/lock.sh` prefers the Quickshell lock and falls back to hyprlock
whenever the shell cannot be confirmed — not installed, no answer, an unexpected
answer, or a hang. Test the decision without locking anything:

```bash
./tests/p8-lock-smoke.sh
```

If the Quickshell lock is faulty, force hyprlock permanently by pointing
`lock_cmd` in `~/.config/hypr/hypridle.conf` straight at `hyprlock`.

**If the session is locked with no lock screen drawn**, the lock client died while
holding the session lock. `ext-session-lock` keeps the session locked in that case
deliberately, so a crashed locker cannot expose the desktop. Switch to a TTY
(`Ctrl+Alt+F3`), log in, and either restart the shell or end the session:

```bash
loginctl unlock-session   # ask the compositor to release the lock
# or, as a last resort:
loginctl terminate-user "$USER"
```

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

Reselect with `scripts/07-select-notification-backend.sh --backend quickshell`,
`--backend ags`, `--backend swaync`, or `--backend mako`, then redeploy. The helper
stops the inactive daemon so two cannot compete for the D-Bus service.

Selecting a backend restarts the daemon using the **deployed**
`notification-daemon.sh`. If that copy predates Quickshell support it will not
recognise the name and silently falls through to AGS — deploy first, then select.

Confirm which daemon actually owns the bus:

```bash
busctl --user get-property org.freedesktop.Notifications \
    /org/freedesktop/Notifications org.freedesktop.Notifications ServerInformation
```

## Reset motion safely

```bash
mv "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/motion-profile" \
   "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/motion-profile.manual-backup"
~/.config/hypr/scripts/motion-profile.sh --ensure
```

The safe default is `standard`. A live profile switch that Hyprland rejects is
rolled back automatically.
