# Quick-settings panel (Wi-Fi, Bluetooth, audio, clipboard, notifications)

Hyprveil's shell includes a glass **quick-settings panel** built with
[Quickshell](https://quickshell.outfoxxed.me/) (QML). It unifies three controls that
otherwise live in separate places or external apps:

- **Wi-Fi** — enable/disable and a signal-sorted network list you can click to
  connect, driven by `Quickshell.Networking`. A known or open network connects
  in-process; an unknown secured one hands off to `nmcli`, which triggers
  NetworkManager's own secret agent rather than asking the shell to handle your
  passphrase. If `nmcli` is absent, the panel raises a notification instead of
  presenting a dead connection row.
- **Bluetooth** — adapter power toggle plus a device list with connect/disconnect
  and battery percentage where the device reports one, driven by
  `Quickshell.Bluetooth`. Connect and disconnect also raise notifications.
  Pairing new devices opens Blueman as the integrated agent fallback rather than
  reimplementing BlueZ authentication prompts in the shell.
- **Audio** — output and input device selection, mute-on-middle-click, volume
  sliders, and per-stream controls where PipeWire exposes active application
  streams, driven by `Quickshell.Services.Pipewire`. A footer button opens the
  full GNOME sound settings page for routing or device options the shell does not
  own.
- **Power** — laptop power-profile controls for performance, balanced, and power
  saver modes when `powerprofilesctl` exposes them. Unsupported systems show a
  small unavailable state instead of a dead control.
- **Clipboard** — searchable `cliphist` history with click-to-copy, clear-item,
  and clear-all actions. It uses the same history populated by the `SUPER+V`
  binding.
- **Notifications** — history cards, clear-all, and a do-not-disturb toggle, with
  transient top-right popups. The shell *is* the notification daemon, so the
  history you read here holds the same objects that appeared as toasts.
- **Wallpapers** — a "Wallpapers..." row opens the picker.
- **Keyboard shortcuts** — a "Keyboard shortcuts…" row opens the cheatsheet.
  See [Keybind cheatsheet](#keybind-cheatsheet) below.

## Opening the panel

- **`SUPER+N`** toggles the full panel. The keybind calls
  `hypr/scripts/notification-daemon.sh toggle`, which dispatches per backend — it
  has never called the shell directly, which is why the binding survived the
  migration from the retired AGS panel unchanged.
- **The bar's bell glyph** opens the same window showing the notification
  section alone: a bell that answers with Wi-Fi and Bluetooth is not the control
  the glyph promised. Clicking it while the full panel is open switches the view
  rather than closing, so the bell never needs two clicks. Right-click toggles
  do-not-disturb without opening anything.
- Click the Bluetooth, network, or volume action in the bar to open that section
  inside Hyprveil's own panel. Clicking the same active action closes it; clicking
  another switches sections in place. Contextual views include an **All
  settings…** route back to the complete stack. The Audio section still links to
  GNOME sound settings for advanced routing the shell does not own.

## Single bar

The top bar is one transparent layer-shell reservation with a single glass
surface: workspaces and the active app on the left, a stable date/clock in the
real screen center, and media/status/actions on the right. A Quickshell `Region`
mask keeps the outer margins click-through rather than invisible input blockers.

The layout responds to each monitor's logical width. At 1600px and wider it
shows the active title, media label, system monitors, and tray icons inline when
they fit; larger trays use the drawer so they cannot cross the center clock. From
1280–1599px it keeps a shorter media label, collapses the tray, and hides
system-monitor detail.
Below 1280px it keeps workspaces, a shorter date/clock, and essential status
actions. Hidden wallpaper, Bluetooth, and system detail remain available from
Quick Settings.

Bar actions share a 40px hit target, hover/pressed states, accessible names, and
layer-shell-safe anchored tooltips. Media detail and a compact tray drawer use
the same anchored-popup behavior, including edge adjustment.

When the notification backend is SwayNC or Mako instead of Quickshell, the panel
is inactive and `SUPER+N` falls back to that backend's own control centre.

## Where it lives

A normal Quickshell config under `config/quickshell/` (deployed to
`~/.config/quickshell`, which is Quickshell's default config path — so it runs as
plain `quickshell` with no `-c`):

| File | Role |
|---|---|
| `shell.qml` | Entry point; instantiates the bar and dock per monitor, plus the notification server, panel, lock, and Bluetooth watcher. |
| `Panel/QuickSettings.qml` | Panel container, the `quicksettings` IPC target, Escape-to-close. |
| `Bar/Bar.qml` / `BarIsland.qml` | Responsive single-bar composition and shared adaptive glass wrapper. |
| `Bar/BarAction.qml` / `BarTooltip.qml` | Shared action states, accessibility, and anchored tooltips. |
| `Bar/Media.qml` / `MediaCard.qml` | Compact media chip and its artwork, timeline, seek, and transport popup. |
| `Panel/WifiSection.qml` / `BluetoothSection.qml` / `AudioSection.qml` / `PowerProfileSection.qml` / `ClipboardSection.qml` / `NotificationSection.qml` | The sections. |
| `Panel/Section.qml` / `Toggle.qml` / `Segmented.qml` | Shared section chrome, the switch, and the segmented control. |
| `Panel/Wallpapers.qml` | Modal thumbnail grid; renders `wallpaper.sh list`, stages a choice, and calls `wallpaper.sh apply` on **Apply**. |
| `Panel/Button.qml` | Push button for panel footers; `primary: true` is the confirming action. |
| `Panel/LinkRow.qml` | Full-width panel row that hands off to another surface (Wallpapers, Keyboard shortcuts). |
| `Panel/Cheatsheet.qml` | Modal keybind cheatsheet; renders `Services/Keybinds` in two balanced columns with a search field. |
| `Panel/BindRow.qml` | One cheatsheet row: the action, and the key caps for it. |
| `Osd/Osd.qml` | Coalesced volume, microphone mute, and brightness overlay driven by hardware-key helper calls. |
| `Services/Keybinds.qml` | Parses `hypr/keybindings.conf` into sections, groups, and binds. The only thing that knows the bind syntax. |
| `Lock/Lock.qml` | The session lock — see [RECOVERY.md](RECOVERY.md). |
| `Bar/Tray.qml` / `TrayItem.qml` | Inline system tray or compact popup drawer with anchored native menus. |
| `Dock/` | Application dock. |
| `Dock/PinPicker.qml` | Modal pin picker; renders `dock-manager.sh entries`, stages a list, and calls `dock-manager.sh set` on **Apply**. |
| `Services/Pins.qml` / `BluetoothWatch.qml` | Dock pin state and Bluetooth notifications. |
| `Services/Icons.qml` | The icon fallback chain, shared by the dock tiles and the pin picker. |
| `Notif/Popups.qml` | The notification server and popup stack. |
| `Notif/NotificationCard.qml` | One card, shared by popups and history. |
| `Tokens.qml` | **Generated** from the design tokens documented in [CONFIGURATION.md](CONFIGURATION.md). |
| `Accent.qml` | **Generated** from the wallpaper accent documented in [CONFIGURATION.md](CONFIGURATION.md). |
| `qmldir`, `Services/qmldir` | Component registration. Read the note below before adding a file. |

Blur is also applied to `hyprveil-wallpapers`, `hyprveil-dock-pins`,
`hyprveil-cheatsheet`, and `hyprveil-osd`; every shell surface needs its own
`layerrule`.

### qmldir is not optional

A `pragma Singleton` file with no `qmldir` entry resolves to the uninstantiated
*type* rather than its instance. `Tokens.radiusMd` then reads as `undefined`, and
QML renders an undefined radius as `0` **without raising anything** — the shell
loads and looks plausible with the entire token scale unbound.

Adding a `qmldir` also *replaces* implicit same-directory resolution rather than
extending it, so every component in that directory has to be listed, not just the
singletons. Both halves are written into the files themselves.

Shared panel controls (`Button`, `Toggle`, `Segmented`, and `LinkRow`) accept
keyboard focus, draw an accent focus ring, expose accessible names, and activate
from Enter or Space. Segmented controls also move between choices with Left and
Right. The custom rows inside Wi-Fi, Bluetooth, audio, clipboard, and
notifications follow the same focus and activation pattern.

The modal close buttons, wallpaper thumbnails, dock-pin chips, and dock-pin app
rows follow that same pattern. The lock screen keeps password focus on one owner
for safety, so media transport is mirrored there through hardware media keys
instead of tab-focusable child buttons.

Hyprland gives the panel, bar, dock, and popups their blur via `layerrule = blur`
on the `hyprveil-quicksettings`, `hyprveil-bar`, `hyprveil-dock`, and
`hyprveil-notifications` namespaces (`config/hypr/window-rules.conf`). Modal shell
surfaces and the OSD have their own namespaces in the same file. The glass is the
compositor's, not the toolkit's: a surface with no blur rule renders flat no matter
what the QML asks for.

## Keybind cheatsheet

`SUPER+/`, or the "Keyboard shortcuts…" row in the panel, opens a modal listing
every bind. `Services/Keybinds.qml` parses `~/.config/hypr/keybindings.conf` and
the modal renders whatever it finds, so **the config is the only source of
truth** — a bind you add appears without touching the shell, and the cheatsheet
cannot drift from the scheme the way the README's hand-written table can.

The file's existing comment conventions carry the structure:

- `##! Window` opens a section, becoming a card. Anything after the first `(`,
  `—`, or `:` is treated as a note to whoever edits the file, not a heading.
- A plain `#` comment becomes the heading for the binds beneath it, up to the
  next blank line.

Two things are rewritten rather than shown raw. `$mod SHIFT, S` becomes the caps
`Super` `Shift` `S`, and runs of per-digit binds collapse to one `1 – 0` row —
the workspace section is otherwise thirty rows saying three things. The count in
the header is deliberately the number of **binds in the file**, not rows on
screen, so collapsing does not make the scheme look a third smaller than it is.

Actions are shown as the command that actually runs (`$terminal` resolved to
`kitty`, script directories stripped) rather than a hand-written label, for the
same reason: a label is a second source of truth that goes stale the first time
the command changes.

`tests/manual/cheatsheet/probe.qml` opens the modal standalone, so checking a
change to it does not mean restarting the shell and discarding the session's
notification history.

## Talking to the shell

Quickshell exposes typed IPC. `qs ipc show` lists every target:

```bash
qs ipc call quicksettings toggle     # open/close the panel
qs ipc call notifications dnd        # toggle do-not-disturb
qs ipc call notifications count      # tracked notification count
qs ipc call notifications clear      # dismiss everything
qs ipc call wallpapers toggle        # open/close the wallpaper grid
qs ipc call dockpins toggle          # open/close the dock pin picker
qs ipc call cheatsheet toggle        # open/close the keybind cheatsheet
qs ipc call osd show volume 42 false # show the coalesced media-key overlay
qs ipc call lock isLocked            # lock state
```

There is deliberately **no unlock over IPC**. Anything that can reach the socket
could otherwise bypass the lock screen; `tests/p8-lock-smoke.sh` asserts no such
function appears.

## Dependencies

Quickshell comes from the `errornointernet/quickshell` COPR, installed behind the
installer's COPR-consent prompt. Wi-Fi uses NetworkManager, Bluetooth uses BlueZ,
pairing opens Blueman as the agent fallback, audio controls use PipeWire through
Quickshell, power profiles use `powerprofilesctl` when `power-profiles-daemon` is
installed and exposes profiles, clipboard history uses `cliphist` and `wl-copy`,
and notifications from scripts use `notify-send` (`libnotify`).

There is **no Sass step**. AGS compiled a stylesheet on every start and needed a
`sass` binary on `PATH` or the whole shell failed to launch, taking notifications
with it. QML has real properties, so the accent and token singletons are plain
generated files.

## Editing and reloading

Edit files under `~/.config/quickshell` and Quickshell hot-reloads —
`Quickshell.watchFiles` defaults to true, which is also why writing `Accent.qml`
*is* the accent reload with nothing to push.

One caveat: the watcher tracks the paths it started with. Replacing
`~/.config/quickshell` wholesale — which is exactly what the installer's staged
deploy does — leaves a running instance watching paths that no longer exist. After
an upgrade, restart it:

```bash
~/.config/hypr/scripts/notification-daemon.sh restart
```

Note that restarting discards the session's notification history, since the shell
is the notification server.
