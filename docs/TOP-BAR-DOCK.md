# Top bar media, Bluetooth, and dock pins

The bar and dock are drawn by the Quickshell shell (`config/quickshell/Bar/` and
`Dock/`). Both appear on every monitor: one `Variants` block per surface
re-instantiates its delegate for each screen, so hotplugging a display is handled
by the model changing rather than by any configuration of yours.

The bar shows Bluetooth only when BlueZ reports a controller. A powered controller
with no connections reads as enabled; connected devices are listed in the tooltip
with battery percentages where BlueZ exposes them. Left-click opens Blueman.

The MPRIS area is a previous/play-pause/next cluster followed by an
`artist — title` label, so it reads as one balanced group rather than icons split
across both ends. It controls the first playing MPRIS player, or the first paused
one when nothing is playing, and the whole area hides when no usable player exists.
The label elides at a width rather than truncating at a character count — a count
guesses at rendered width and gets it wrong for any title that is not mostly Latin.

Under Waybar this was four separate modules, each spawning `playerctl` every two
seconds, because a Waybar module has exactly one click target. MPRIS is a property
subscription: nothing runs until the player state changes.

## Opening the panels

Two buttons sit between the status cluster and the clock. The picture glyph opens
the wallpaper picker; the bell opens quick settings, and right-clicking it toggles
do-not-disturb without opening anything — muting is what you want at the moment a
toast interrupts you, and going through the panel costs three clicks.

The bell carries a badge counting notification *history*, not the toasts currently
on screen: a notification that timed out unread is precisely the case the button
exists to surface, and counting popups would read zero exactly then. The count is
capped at `9+`, because past a few unread the exact number stops being the
information and the badge is a fixed circle on a 24px glyph.

Both panels remain reachable the way they always were — `SUPER+N` for quick
settings, and `qs ipc call wallpapers toggle` — and both are single session-wide
scopes rather than one per monitor, so every bar toggles the same panel and their
button states cannot disagree.

## Managing dock pins

The cog at the right end of the dock opens the pin picker. It lists every
installed application with a search field, and clicking a row stages or unstages
it; the strip along the top shows what the dock will hold, in order, and clicking
one of those chips removes it. Nothing is written until Apply, so a misclick in a
list of several hundred apps costs a second click rather than a dock.

Before this the dock's own contents were the one thing on the dock you could not
change from the dock — pinning went through a Rofi menu you had to already know
about. That menu is still there (`dock-manager.sh manage`) and still works.

### Reordering by dragging

Press and hold a pinned tile for 400ms. It lifts out of the row and follows the
pointer, and an accent bar marks the gap it will drop into; release to commit.
Only pinned tiles participate — a running window that is not pinned has no stored
position, so there would be nothing for a drop to write.

The row is not reordered live while you drag. The dock's model is a plain
JavaScript array, so a `Repeater` rebuilds every delegate when it changes, which
would destroy the tile mid-drag and take the mouse grab with it. The indicator
shows the destination instead and the model updates once, on release.

The lift is deliberately larger than the hover scale and, unlike a press, does not
dip below rest: the tile has left the row and is attached to the pointer, so it
must not still read as "being clicked". A press that is cancelled — the compositor
taking the grab, the shell reloading mid-drag — returns the tile to its slot
without writing anything, because committing a reorder nobody asked for is the
worse failure.

### From the command line

```bash
~/.config/hypr/scripts/dock-manager.sh list
~/.config/hypr/scripts/dock-manager.sh entries
~/.config/hypr/scripts/dock-manager.sh add org.mozilla.firefox.desktop
~/.config/hypr/scripts/dock-manager.sh remove org.mozilla.firefox.desktop
~/.config/hypr/scripts/dock-manager.sh move org.mozilla.firefox.desktop first
~/.config/hypr/scripts/dock-manager.sh set kitty.desktop org.mozilla.firefox.desktop
```

`entries` is the catalogue the picker renders, and it ships the pin limit alongside
the applications so the picker enforces the same ceiling this script does rather
than hardcoding a second copy of the number.

`set` replaces the whole list in one write, which is what Apply commits: add,
remove, and reorder arrive together instead of as a sequence of `add` and `remove`
calls that would take the lock once each and render every intermediate dock on the
way. Every id is resolved *before* the lock is taken, so a typo leaves the existing
pins alone rather than truncating them at the entry that failed. With no arguments
it clears the dock.

The picker is also reachable over IPC, the same shape the wallpaper picker exposes:

```bash
qs ipc call dockpins toggle
```

Pin order is stored atomically under `$XDG_STATE_HOME/hyprveil/dock-pins.json`
(normally `~/.local/state/hyprveil/dock-pins.json`), outside the installer-managed
configuration trees, so an upgrade preserves it. The shell watches that file, so
pins added from the Rofi manager appear immediately with nothing to signal.

Malformed state is copied beside the state file with an `.invalid-TIMESTAMP`
suffix, then replaced with an empty valid array. Other Hyprveil state is untouched.
The shell independently rejects a malformed file and falls back to showing running
windows only, rather than rendering a dock with missing tiles and no explanation.

### The ten-pin limit is gone

Waybar could not render a dynamic list, so the dock was ten hand-duplicated
`custom/dock-0..9` modules and `DOCK_LIMIT` was that fixed pool's size wearing a
policy hat. The Quickshell dock is a `Repeater` over a model and has no such
ceiling. `dock-manager.sh` still enforces its own limit; that is now a choice
rather than a constraint.

## Click behaviour

Left-click focuses a running window or launches a closed pin through its desktop
entry, middle-click closes a running window, right-click toggles the pin, and a
long press starts a drag. The
desktop-entry route is what makes Flatpak and Electron launch commands work without
treating a window class as an executable. Where no entry can be resolved, the click
falls through to `gtk-launch` with the pinned desktop id, so the tile still starts
the app instead of doing nothing.

Icons come from `Quickshell.Io.DesktopEntries` resolved through the icon theme.
Waybar could not draw an icon and a label in the same button, which is why six apps
previously had hardcoded `background-image` rules pointing at absolute Papirus
paths, with everything else falling back to a glyph from a 29-entry lookup table.
Both are gone.

`DesktopEntries` does not index anything on every Quickshell build — 0.3.0 from the
Fedora COPR returns an empty model — so icons resolve as a chain rather than a
single lookup: the entry's declared `Icon=`, then the desktop id
without its suffix, then the window class, then `application-x-executable`. Each
candidate is checked against the icon theme (`Quickshell.iconPath(name, true)`,
which returns an empty string when the theme has no such icon) instead of being
assumed to resolve. Keying tile visibility on the desktop entry alone is what
previously emptied the dock of every logo on those builds.

The chain lives in `config/quickshell/Services/Icons.qml` rather than in the tile,
because the pin picker resolves icons for applications that have no tile yet — and
two copies of a fallback chain drift.

## Reserved space

Both surfaces reserve their strip through the layer-shell exclusive zone, so a
maximised window sits between them rather than running underneath. The dock
previously pinned `exclusiveZone: 0`, which put the last rows of a tiled window
under the tiles and out of reach.

Every tile renders at full strength, whichever workspace its window is on.
Dimming off-workspace apps read as "disabled" when in fact clicking one is how
you switch to it; the running dot carries open/closed on its own.
