# Notification center and fallback

**Quickshell** is Hyprveil's default backend. It is the session shell — bar, dock,
lock screen, and the unified quick-settings panel (see
[QUICK-SETTINGS.md](QUICK-SETTINGS.md)) — *and* the notification daemon, in one
process. It provides top-right popup cards, a history section with clear-all,
inline actions, and a do-not-disturb toggle. `SUPER+N` toggles the panel.

Because the shell owns the notification server, **restarting it discards the
session's notification history**. That constraint shapes the design: the accent and
token singletons are watched files rather than a push, so a wallpaper change
recolours the shell without restarting it.

**SwayNC** is a fallback for a dedicated control center, and **Mako** a minimal
fallback. Only one daemon ever runs. The rest of this document covers all three
backends.

## Bluetooth notifications

With the Quickshell backend, Bluetooth devices raise notifications when they
connect or disconnect, and when a device that reports its battery drops below 20%
and again below 10%.

Three rules keep this usable rather than noisy: already-connected devices do not
announce themselves at login; connect/disconnect is debounced for 1.5 seconds,
because BlueZ toggles `connected` several times while pairing and on reconnect; and
battery warnings latch per threshold, re-arming only after the device recovers, so
a headset sitting at 9% warns once rather than on every update.

These go out through `notify-send` rather than being injected internally, so they
land in history and honour do-not-disturb exactly like any other notification.

Pairing *requests* are not handled in the shell. That needs an `org.bluez.Agent1`
registration, and two agents cannot both be the default — keep `blueman-applet`
running if you pair devices from the desktop.

## SwayNC fallback

SwayNC provides top-right popup cards, notification history, inline actions, mouse
and keyboard dismissal, a clear-all button, and a do-not-disturb switch whose value
SwayNC restores after a restart. `SUPER+N` toggles the control center, routed
through `notification-daemon.sh` like every other backend.

### The fallback backends have no bar

Only Quickshell draws a bar and dock. SwayNC and Mako are notification daemons,
so selecting one leaves the session without a bar unless you start one yourself:

```bash
waybar & disown
```

`config/waybar/` is still deployed for exactly that: its config and dock scripts
work, they are simply no longer started for you. `autostart.conf` cannot make this
conditional — it has no way to read the selected backend — and starting Waybar from
`notification-daemon.sh` instead was tried and reverted, because a racing start
guard produced several stacked instances on a live session. Starting it by hand is
the honest behaviour rather than a clever one that fails badly.

Treat these as fallbacks for when the shell will not run, not as like-for-like
alternatives.

The control center is more than a notification list: above the history it shows the
active MPRIS media player (when one exists), a row of quick-action buttons (lock,
pick a wallpaper, open `pavucontrol`, open the power menu), and a volume slider
mirroring the `wpctl`-driven volume keybindings. Each mirrors an action already bound
elsewhere in Hyprveil, so nothing here is a new dependency or a new source of truth
for state.

Inside the center, Up/Down and Home/End navigate, Enter invokes the default action,
number keys invoke alternative actions, and Delete or Backspace dismisses the
selected notification. `SHIFT+C` clears history and `SHIFT+D` toggles DND. Mouse
actions and the per-card close button provide the same operations.

## Backend selection

The installer probes Fedora repositories first, then offers Quickshell from the
`errornointernet/quickshell` COPR. Declining the COPR does not change repository
configuration; the installer then offers SwayNC (`erikreider/SwayNotificationCenter`
COPR) and, if that is also declined, selects Mako from Fedora's official
repositories. Mako retains styled popup notifications and a session-persistent DND
mode, but it cannot provide a history panel.

The choice is stored in
`$XDG_STATE_HOME/hyprveil/notification-backend` (normally
`~/.local/state/hyprveil/notification-backend`). Change it with:

```bash
./scripts/07-select-notification-backend.sh --backend quickshell
./scripts/07-select-notification-backend.sh --backend swaync
./scripts/07-select-notification-backend.sh --backend mako
```

> **Upgrading in a live session.** Selecting a backend restarts the running daemon
> using the *deployed* `notification-daemon.sh`. If that copy predates Quickshell
> support it will not recognise the name and will silently fall through to its own
> default. Deploy first, then select. A fresh install is unaffected.

Then run the full installer to install the selected package and safely redeploy its
config. On the next login, `notification-daemon.sh` stops the inactive daemon before
starting the selected one. In a live session:

```bash
~/.config/hypr/scripts/notification-daemon.sh restart
```

With the Quickshell backend that one command also restarts the bar and dock — they
are the same process.

Reload SwayNC configuration and CSS without restarting it:

```bash
swaync-client --reload-config
swaync-client --reload-css
```

For the Mako fallback, use `makoctl reload`. Quickshell hot-reloads on file change,
so editing under `~/.config/quickshell` is usually enough; after an upgrade
replaces the directory wholesale the watcher needs the backend-aware restart
helper. If notifications stop, check the saved backend, confirm its command
exists, and restart the helper:

```bash
cat "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/notification-backend"
~/.config/hypr/scripts/notification-daemon.sh restart
```

Check which notifications the shell currently holds without opening the panel:

```bash
qs ipc call notifications count
```
