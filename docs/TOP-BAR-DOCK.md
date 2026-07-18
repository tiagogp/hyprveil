# Top bar media, Bluetooth, and dock pins

The Waybar top bar shows Bluetooth only when BlueZ reports a controller. A powered
controller with no connections has an enabled state; connected devices are listed
in the tooltip with battery percentages when BlueZ exposes them. Left-click opens
Blueman. If Blueman is absent, a desktop notification explains which package to
install without stopping Waybar.

The MPRIS area is a previous/play-pause/next control cluster followed by an
`artist — title` label, so the pill always reads as one balanced group instead of
icons split across both ends of the label. It controls the first playing Playerctl
player, or the first paused player when none is playing. Stale players are skipped
and the entire area hides when no usable player exists. Labels are markup-escaped
and shortened to 48 characters. Only the play/pause icon toggles playback; the
label itself has no click action.

## Managing dock pins

Right-click the dock launcher to open the Rofi manager. It can show the current
order, add applications from installed desktop entries, remove pins, and move them
up, down, first, or last. The same operations are scriptable:

```bash
~/.config/waybar/scripts/dock-manager.sh list
~/.config/waybar/scripts/dock-manager.sh add org.mozilla.firefox.desktop
~/.config/waybar/scripts/dock-manager.sh remove org.mozilla.firefox.desktop
~/.config/waybar/scripts/dock-manager.sh move org.mozilla.firefox.desktop first
```

The dock keeps at most ten pins. Pin order is stored atomically under
`$XDG_STATE_HOME/hyprveil/dock-pins.json` (normally
`~/.local/state/hyprveil/dock-pins.json`) and is outside the installer-managed
configuration trees, so an upgrade preserves it. Existing class/command pins are
migrated in place when their desktop entry can be found. An unresolved old pin stays
in order and remains removable, but will not execute its former guessed command.

Malformed state is copied beside the state file with an `.invalid-TIMESTAMP` suffix,
then replaced with an empty valid array. Other Hyprveil state is not touched.

Dock slot clicks retain their direct behavior: left-click focuses a running window
or launches a closed pin through its desktop entry, middle-click closes a running
window, and right-click toggles the pin. The desktop-entry route is what makes
Flatpak and Electron launch commands work without treating a window class as an
executable.
