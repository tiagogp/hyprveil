# Wallpaper-derived accent

Hyprveil can derive the accent color from the active wallpaper and render it into
the components that cannot read one shared theme file.

The fixed dark neutral palette still lives in `config/hypr/colors.conf`. The moving
accent family is stored in `$XDG_STATE_HOME/hyprveil/accent.json` and rendered by
`~/.config/hypr/scripts/accent.sh` into:

| Target | Generated file |
|---|---|
| Hyprland / hyprlock | `~/.config/hypr/accent.conf` |
| Waybar, SwayNC, wlogout, GTK3, GTK4 | `accent.css` next to each stylesheet |
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

Wallpaper changes call `accent.sh from-wallpaper` when automatic tracking is on.
If ImageMagick is missing or the image has no reliable hue, wallpaper selection
still succeeds and the designed accent (`#e14658`) is kept.

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
