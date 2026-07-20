# Wallpaper-derived accent

Hyprveil can derive the accent color from the active wallpaper and render it into
the components that cannot read one shared theme file.

The fixed dark neutral palette still lives in `config/hypr/colors.conf`. The moving
accent family is stored in `$XDG_STATE_HOME/hyprveil/accent.json` and rendered by
`~/.config/hypr/scripts/accent.sh` into:

| Target | Generated file |
|---|---|
| Hyprland / hyprlock | `~/.config/hypr/accent.conf` |
| SwayNC, wlogout, GTK3, GTK4, Waybar | `accent.css` next to each stylesheet |
| Quickshell (bar, dock, panel, lock) | `~/.config/quickshell/Accent.qml` |
| AGS | `~/.config/ags/_accent.scss` |
| Rofi | `~/.config/rofi/accent.rasi` |
| Kitty | `~/.config/kitty/accent.conf` |
| Mako, Qt, wlogout SVG icons | Rendered from `.in` templates |

## Commands

```bash
~/.config/hypr/scripts/accent.sh from-wallpaper "/path/to/image.jpg"
~/.config/hypr/scripts/accent.sh set "#5fc593"
~/.config/hypr/scripts/accent.sh reset
~/.config/hypr/scripts/accent.sh current
~/.config/hypr/scripts/accent.sh auto on
~/.config/hypr/scripts/accent.sh auto off
```

## When the accent is derived

With automatic tracking on (the default), the accent follows the wallpaper at
three points:

- **Picking a wallpaper** — `wallpaper.sh apply` calls `from-wallpaper` with the
  chosen image, so `SUPER+SHIFT+W` recolors the desktop as well as the background.
- **Logging in** — `wallpaper.sh restore` re-derives from the fallback wallpaper,
  so the accent survives a session restart and cannot drift from the background.
  A per-monitor override does not change this: the fallback is the system-wide
  selection, and deriving once per screen would reload every component per screen.
- **Reinstalling** — `install.sh` runs `accent.sh render` after replacing the
  managed config trees, which otherwise restore the default-red fragments.

If ImageMagick is missing or the image has no reliable hue, wallpaper selection
still succeeds and the designed accent (`#e14658`) is kept. Nothing on these paths
is fatal — a failed extraction warns and never blocks a wallpaper change or a login.

Applying an accent reloads Hyprland, Waybar, SwayNC, and Mako in place. The AGS
shell is also the notification daemon, so rather than restarting it (which would
discard the session's notification history) `accent.sh` recompiles `style.scss`
with dart-sass and pushes the result via `ags request reload-css`. Without
dart-sass installed the panel keeps its old accent until it next restarts.

## Editing

Edit the neutral palette in the normal stylesheet or config file. Edit generated
accent files only through `accent.sh`, because installer reruns and wallpaper
changes will rewrite them.

For formats without imports, edit the `.in` template beside the managed output:

- `config/mako/config.in`
- `config/qt5ct/colors/hyprveil.conf.in`
- `config/qt6ct/colors/hyprveil.conf.in`
- `config/wlogout/assets/src/*-accent.svg`

Run `accent.sh render` after changing templates to regenerate the deployed files
from the saved state.
