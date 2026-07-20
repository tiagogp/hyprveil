# Quick-settings panel (Wi-Fi, Bluetooth, notifications)

Hyprveil's shell includes a glass **quick-settings panel** built with
[Quickshell](https://quickshell.outfoxxed.me/) (QML). It unifies three controls that
otherwise live in separate places or external apps:

- **Wi-Fi** — enable/disable and a signal-sorted network list you can click to
  connect, driven by `Quickshell.Networking`. A known or open network connects
  in-process; an unknown secured one hands off to `nmcli`, which triggers
  NetworkManager's own secret agent rather than asking the shell to handle your
  passphrase.
- **Bluetooth** — adapter power toggle plus a device list with connect/disconnect
  and battery percentage where the device reports one, driven by
  `Quickshell.Bluetooth`. Connect and disconnect also raise notifications — see
  [NOTIFICATIONS.md](NOTIFICATIONS.md#bluetooth-notifications).
- **Notifications** — history cards, clear-all, and a do-not-disturb toggle, with
  transient top-right popups. The shell *is* the notification daemon, so the
  history you read here holds the same objects that appeared as toasts.
- **Wallpapers** — a "Wallpapers…" row opens the picker. See
  [WALLPAPERS-MOTION.md](WALLPAPERS-MOTION.md#wallpaper-picker).

## Opening the panel

- **`SUPER+N`** toggles it. The keybind calls
  `hypr/scripts/notification-daemon.sh toggle`, which dispatches per backend — it
  has never called the shell directly, which is why the binding survived the
  migration from AGS unchanged.
- Click the Bluetooth or network glyph in the bar for the external managers
  (`blueman-manager`, `nm-connection-editor`).

When the notification backend is SwayNC or Mako instead of Quickshell (see
[NOTIFICATIONS.md](NOTIFICATIONS.md)), the panel is inactive and `SUPER+N` falls
back to that backend's own control centre.

## Where it lives

A normal Quickshell config under `config/quickshell/` (deployed to
`~/.config/quickshell`, which is Quickshell's default config path — so it runs as
plain `quickshell` with no `-c`):

| File | Role |
|---|---|
| `shell.qml` | Entry point; instantiates the bar and dock per monitor, plus the notification server, panel, lock, and Bluetooth watcher. |
| `Panel/QuickSettings.qml` | Panel container, the `quicksettings` IPC target, Escape-to-close. |
| `Panel/WifiSection.qml` / `BluetoothSection.qml` / `NotificationSection.qml` | The sections. |
| `Panel/Section.qml` / `Toggle.qml` / `Segmented.qml` | Shared section chrome, the switch, and the segmented control. |
| `Panel/Wallpapers.qml` | Thumbnail grid; renders `wallpaper.sh list` and calls `wallpaper.sh apply`. |
| `Lock/Lock.qml` | The session lock — see [RECOVERY.md](RECOVERY.md). |
| `Bar/` / `Dock/` | Bar modules and the dock — see [TOP-BAR-DOCK.md](TOP-BAR-DOCK.md). |
| `Services/Pins.qml` / `BluetoothWatch.qml` | Dock pin state and Bluetooth notifications. |
| `Notif/Popups.qml` | The notification server and popup stack. |
| `Notif/NotificationCard.qml` | One card, shared by popups and history. |
| `Tokens.qml` | **Generated** from the design tokens — see [TOKENS.md](TOKENS.md). |
| `Accent.qml` | **Generated** from the wallpaper accent — see [ACCENT.md](ACCENT.md). |
| `qmldir`, `Services/qmldir` | Component registration. Read the note below before adding a file. |

Blur is also applied to `hyprveil-wallpapers`; every shell surface needs its own
`layerrule`.

### qmldir is not optional

A `pragma Singleton` file with no `qmldir` entry resolves to the uninstantiated
*type* rather than its instance. `Tokens.radiusMd` then reads as `undefined`, and
QML renders an undefined radius as `0` **without raising anything** — the shell
loads and looks plausible with the entire token scale unbound.

Adding a `qmldir` also *replaces* implicit same-directory resolution rather than
extending it, so every component in that directory has to be listed, not just the
singletons. Both halves are written into the files themselves.

Hyprland gives the panel, bar, dock, and popups their blur via `layerrule = blur`
on the `hyprveil-quicksettings`, `hyprveil-bar`, `hyprveil-dock`, and
`hyprveil-notifications` namespaces (`config/hypr/window-rules.conf`). The glass is
the compositor's, not the toolkit's: a surface with no blur rule renders flat no
matter what the QML asks for.

## Talking to the shell

Quickshell exposes typed IPC. `qs ipc show` lists every target:

```bash
qs ipc call quicksettings toggle     # open/close the panel
qs ipc call notifications dnd        # toggle do-not-disturb
qs ipc call notifications count      # tracked notification count
qs ipc call notifications clear      # dismiss everything
qs ipc call wallpapers toggle        # open/close the wallpaper grid
qs ipc call lock isLocked            # lock state
```

There is deliberately **no unlock over IPC**. Anything that can reach the socket
could otherwise bypass the lock screen; `tests/p8-lock-smoke.sh` asserts no such
function appears.

## Dependencies

Quickshell comes from the `errornointernet/quickshell` COPR, installed behind the
installer's COPR-consent prompt. Wi-Fi uses NetworkManager, Bluetooth uses BlueZ,
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
qs kill && ~/.config/hypr/scripts/notification-daemon.sh start & disown
```

Note that restarting discards the session's notification history, since the shell
is the notification server.
