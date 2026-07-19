# Quick-settings panel (Wi-Fi, Bluetooth, notifications)

Hyprveil's default shell adds a glass **quick-settings panel** built with
[AGS v2 / Astal](https://aylur.github.io/ags/) (TypeScript + GTK layer-shell). It
unifies three controls that previously lived in separate places or external apps:

- **Wi-Fi** — enable/disable, rescan, and a signal-sorted network list you can click
  to connect, driven by `AstalNetwork`. Secured joins use the running NetworkManager
  secret agent (via `nmcli`). An "Advanced settings…" row still opens
  `nm-connection-editor`.
- **Bluetooth** — adapter power toggle plus a device list with connect/disconnect and
  battery percentage, driven by `AstalBluetooth`. "Open Blueman…" remains available.
- **Notifications** — history cards, clear-all, and a do-not-disturb toggle, with
  transient top-right popups. AGS is the notification daemon (`AstalNotifd`), so this
  is the same system that shows your popups — see
  [NOTIFICATIONS.md](NOTIFICATIONS.md).
- **Wallpapers** — a "Wallpapers…" row opens a thumbnail grid for picking a
  background per monitor. See
  [WALLPAPERS-MOTION.md](WALLPAPERS-MOTION.md#wallpaper-picker).

## Opening the panel

- **`SUPER+N`** toggles it (backend-aware: it opens the AGS panel when AGS is the
  selected notification backend).
- **Left-click** the Waybar Wi-Fi, Bluetooth, or notification icon.
- Right-click the Wi-Fi/Bluetooth icons for the classic external managers, and
  right-click the notification icon for DND.

When the notification backend is SwayNC or Mako instead of AGS (see
[NOTIFICATIONS.md](NOTIFICATIONS.md)), the panel is inactive and those Waybar icons
fall back to `nm-connection-editor` / `blueman-manager`.

## Where it lives

The project is a normal AGS v2 config under `config/ags/` (deployed to
`~/.config/ags`):

| File | Role |
|---|---|
| `app.ts` | Entry point; registers the popup, panel, and wallpaper windows plus the `ags request` handlers (`toggle-quicksettings`, `notif-status`, `notif-dnd`, `notif-clear`, `toggle-wallpapers`) that Waybar and the keybinds call. |
| `widget/QuickSettings.tsx` | Panel container assembling the three sections. |
| `widget/Wifi.tsx` / `Bluetooth.tsx` / `Notifications.tsx` | The sections. |
| `widget/NotificationPopups.tsx` | Transient popups. |
| `widget/Wallpapers.tsx` | Thumbnail wallpaper grid; renders `wallpaper.sh list` and calls `wallpaper.sh apply`. |
| `style.scss` | Glass theme; mirrors `config/hypr/colors.conf` (accent `#e14658`). |

Hyprland gives the panel, popups, and wallpaper grid blur via `layerrule = blur` on
the `hyprveil-quicksettings`, `hyprveil-notifications`, and `hyprveil-wallpapers`
namespaces (`config/hypr/window-rules.conf`).

## Dependencies

AGS v2 (`aylurs-gtk-shell2`) and the Astal libraries (`astal-io`, `astal-notifd`,
`astal-bluetooth`, `astal-network`, `astal-wireplumber`) come from the
`solopasha/hyprland` COPR, installed behind the installer's COPR-consent prompt.
Wi-Fi connect uses `nmcli` (NetworkManager), Bluetooth uses BlueZ. If the COPR is
declined the shell falls back to SwayNC/Mako for notifications and the external
managers for Wi-Fi/Bluetooth.

### Sass

AGS compiles `style.scss` on every start and needs a **`sass` executable on `PATH`**.
Without it the shell fails to start, taking the panel, notifications, and wallpaper
grid with it. Fedora ships no `dart-sass` package, so install it separately:

```bash
npm install -g sass          # dart-sass; the compiler AGS expects
```

Fedora's `sassc` package also compiles this stylesheet, but AGS invokes the binary
by the name `sass`, so `sassc` alone does not satisfy it.

Note that Sass owns `alpha()` as a one-argument function, while GTK CSS uses a
two-argument form. Keep the stylesheet on `rgba($color, $a)`; `alpha($color, $a)`
does not compile and `tests/p5-smoke.sh` fails the build if it reappears.

## Editing and reloading

Edit files under `~/.config/ags` and AGS hot-reloads, or restart it explicitly:

```bash
ags quit -i hyprveil && ags run & disown
```
