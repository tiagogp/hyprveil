# Notification center and fallback

SwayNC is Hyprveil's default notification backend. It provides top-right popup
cards, notification history, inline actions, mouse and keyboard dismissal, a
clear-all button, and a do-not-disturb switch whose value SwayNC restores after a
restart. `SUPER+N` and a left-click on Waybar toggle the control center; right-click
on the Waybar icon toggles DND. The icon distinguishes empty, populated, DND, and
notification-inhibited states.

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

The installer probes Fedora repositories first. If SwayNC is unavailable there, it
explains and offers the `erikreider/SwayNotificationCenter` COPR. Declining the COPR
does not change repository configuration; the installer selects Mako from Fedora's
official repositories instead. Mako retains styled popup notifications and a
session-persistent DND mode, but it cannot provide the SwayNC history panel.

The choice is stored in
`$XDG_STATE_HOME/hyprveil/notification-backend` (normally
`~/.local/state/hyprveil/notification-backend`). Change it with:

```bash
./scripts/07-select-notification-backend.sh --backend swaync
./scripts/07-select-notification-backend.sh --backend mako
```

Then run the full installer to install the selected package and safely redeploy its
config. On the next login, `notification-daemon.sh` stops the inactive daemon before
starting the selected one. In a live session, restart it and Waybar with:

```bash
~/.config/hypr/scripts/notification-daemon.sh restart
pkill waybar; waybar & disown
```

Reload SwayNC configuration and CSS without restarting it:

```bash
swaync-client --reload-config
swaync-client --reload-css
```

For the Mako fallback, use `makoctl reload`. If notifications stop, check the saved
backend, confirm its command exists, stop both daemons, and start the helper:

```bash
cat "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/notification-backend"
pkill swaync; pkill mako
~/.config/hypr/scripts/notification-daemon.sh start
```
