# Wallpapers and motion

Hyprveil stores wallpaper and motion choices outside the managed configuration
tree, so installer reruns and upgrades do not reset them.

## Wallpaper picker

Put JPG, JPEG, PNG, WebP, JXL, or BMP files anywhere below
`~/Pictures/Wallpapers`, then press `SUPER+SHIFT+W`. The Rofi flow asks for an
image, all connected monitors or one connected monitor, and `cover` or `contain`.
An empty or missing wallpaper directory produces a message and makes no state
change.

The helper is also available directly:

```bash
~/.config/hypr/scripts/wallpaper.sh pick
~/.config/hypr/scripts/wallpaper.sh apply "/path/with spaces/image.jpg"
~/.config/hypr/scripts/wallpaper.sh apply "/path/image.png" DP-1 contain
~/.config/hypr/scripts/wallpaper.sh apply "/path/image.png" cover
~/.config/hypr/scripts/wallpaper.sh restore
```

An omitted monitor updates the fallback, clears older per-monitor overrides, and
immediately targets every connected monitor. A named monitor gets its own mapping.
Mappings for disconnected monitors stay saved during restores and are applied when
that output returns; a later explicit all-monitor selection replaces them. At login,
`restore` waits for Hyprpaper IPC, applies the fallback, then overlays valid
connected-monitor choices.

State is schema-checked and atomically written to
`$XDG_STATE_HOME/hyprveil/wallpapers.json` (normally
`~/.local/state/hyprveil/wallpapers.json`). The helper detects the running
Hyprpaper IPC generation: current `wallpaper monitor,path,fit` requests are used
when available, with legacy `reload` or preload/wallpaper requests as fallbacks.

If a selected image disappears, Hyprveil leaves its saved mapping intact but uses
the bundled `~/.config/hypr/wallpaper-default.jpg` for that session. This means a
temporarily unmounted image can resume automatically later. Malformed JSON is
preserved beside the state file as `wallpapers.json.invalid-TIMESTAMP`, then a safe
default state is created. Neither condition prevents login.

## Motion profiles

Choose a profile with:

```bash
~/.config/hypr/scripts/motion-profile.sh standard
~/.config/hypr/scripts/motion-profile.sh reduced
```

`standard` uses restrained window, workspace, layer, and scratchpad movement.
`reduced` uses very short fades and near-zero window scale movement. The selector
atomically saves the choice to `$XDG_STATE_HOME/hyprveil/motion-profile`, updates
`~/.config/hypr/motion/active.conf`, and reloads a running Hyprland session. If the
reload fails, both files are rolled back to the previous profile. Invalid saved
state is preserved as `motion-profile.invalid-TIMESTAMP` and recovers to
`standard`.

To turn animation off completely while retaining either profile, edit:

```text
~/.config/hypr/animations.conf
$hyprveil_animations_enabled = false
```

Then run `hyprctl reload`. Switching motion profiles does not change that global
toggle.

## Recovery

If Hyprpaper is running but the background is wrong, restore the saved selection:

```bash
~/.config/hypr/scripts/wallpaper.sh restore
```

If IPC still fails, restart the daemon and restore again:

```bash
pkill hyprpaper
hyprpaper &
~/.config/hypr/scripts/wallpaper.sh restore
```

To reset wallpaper choices while keeping the bad state for inspection, rename
`wallpapers.json` and run `restore`. To reset motion, rename `motion-profile` and
run `motion-profile.sh --ensure`; the safe default is `standard`.
