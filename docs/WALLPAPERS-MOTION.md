# Wallpapers and motion

Hyprveil stores wallpaper and motion choices outside the managed configuration
tree, so installer reruns and upgrades do not reset them.

## Wallpaper picker

Put JPG, JPEG, PNG, WebP, JXL, or BMP files anywhere below
`~/Pictures/Wallpapers`, then press `SUPER+SHIFT+W`.

There are two front-ends over one helper.

- **Thumbnail grid** (default; the shell's own picker) — a modal dialog centred
  over a dimmed desktop, showing every wallpaper as a thumbnail. Pick the target
  (**All monitors** or a named output) and the fit (**Cover**/**Contain**) at the
  top, then click an image to stage it — the staged tile is outlined in the accent
  color and its name appears in the footer. Nothing is applied until you press
  **Apply**, so a misclick costs a click rather than a wallpaper change;
  double-clicking a tile stages and applies it in one go. **Cancel**, `Escape`, or
  a click on the dimmed area outside the dialog closes it without changing
  anything, and pressing **Apply** closes it too. It is also reachable from the
  "Wallpapers…" row in the quick-settings panel (`SUPER+N`), or with
  `qs ipc call wallpapers toggle`.

- **Rofi flow** — used with the SwayNC and Mako backends, and whenever no shell is
  running. It asks for an image, then all or one connected monitor, then `cover` or
  `contain`. It drives the same helper and writes the same state, so nothing is lost
  by using it — only the previews.

Both write the same state and use the same Hyprpaper IPC, so choices made in one are
visible to the other. An empty or missing wallpaper directory produces a message and
makes no state change.

Thumbnails are scaled once and cached under
`$XDG_CACHE_HOME/hyprveil/wallpaper-thumbs` keyed by file path and modification
time, so reopening the grid is fast and editing an image refreshes its tile. The
cache is disposable — delete it at any time.

The helper is also available directly:

```bash
~/.config/hypr/scripts/wallpaper.sh pick
~/.config/hypr/scripts/wallpaper.sh apply "/path/with spaces/image.jpg"
~/.config/hypr/scripts/wallpaper.sh apply "/path/image.png" DP-1 contain
~/.config/hypr/scripts/wallpaper.sh apply "/path/image.png" cover
~/.config/hypr/scripts/wallpaper.sh list
~/.config/hypr/scripts/wallpaper.sh restore
```

`list` prints the catalog the grid renders — available images, connected outputs,
and the saved fallback plus per-monitor selections — as JSON.

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

If the grid opens empty but `~/Pictures/Wallpapers` has images, check the helper
directly — the grid renders exactly what this prints:

```bash
~/.config/hypr/scripts/wallpaper.sh list
```

If `SUPER+SHIFT+W` opens Rofi when you expected the grid, no shell is running —
`wallpaper.sh pick` tries Quickshell, then falls through to Rofi. Check with
`qs ipc call wallpapers toggle`; see
[QUICK-SETTINGS.md](QUICK-SETTINGS.md).

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
