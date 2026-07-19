// Graphical wallpaper picker: a thumbnail grid over the same state and IPC the
// Rofi flow uses. All directory scanning, schema-checked state, and Hyprpaper IPC
// stay in config/hypr/scripts/wallpaper.sh — this widget only renders `list` and
// calls `apply`, so both pickers can never drift apart.
//
// Toggled via `ags request toggle-wallpapers` (SUPER+SHIFT+W routes here through
// wallpaper.sh pick whenever this shell is running) and the Quick Settings button.
import { Variable, bind, execAsync } from "astal"
import { App, Astal, Gtk } from "astal/gtk3"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import GdkPixbuf from "gi://GdkPixbuf"

const WINDOW = "wallpapers"
const HELPER = GLib.getenv("HYPRVEIL_WALLPAPER_HELPER")
    ?? `${GLib.get_home_dir()}/.config/hypr/scripts/wallpaper.sh`

// 16:9 thumbnails; the grid is three tiles wide.
const THUMB_W = 176
const THUMB_H = 99

type Fit = "cover" | "contain"
type Selection = { path: string; fit: Fit }
type Catalog = {
    dir: string
    images: string[]
    outputs: string[]
    fallback: Selection
    monitors: Record<string, Selection>
}

const catalog = Variable<Catalog | null>(null)
// "" targets every connected monitor, matching `wallpaper.sh apply`'s omitted
// monitor argument.
const target = Variable<string>("")
const fit = Variable<Fit>("cover")
const status = Variable<string>("")

function basename(path: string): string {
    return path.slice(path.lastIndexOf("/") + 1)
}

// What `restore` would apply to the current target, so the grid can mark it.
function activePath(cat: Catalog | null, forTarget: string): string {
    if (!cat) return ""
    const selection = forTarget ? cat.monitors[forTarget] ?? cat.fallback : cat.fallback
    return selection?.path ?? ""
}

async function refresh() {
    try {
        const parsed = JSON.parse(await execAsync([HELPER, "list"])) as Catalog
        // A monitor can disappear between openings; fall back to all monitors
        // rather than silently writing a mapping for a gone output.
        if (target.get() && !parsed.outputs.includes(target.get())) target.set("")
        fit.set((target.get() ? parsed.monitors[target.get()] : parsed.fallback)?.fit ?? "cover")
        catalog.set(parsed)
        status.set("")
    } catch (err) {
        status.set(`Could not read wallpapers: ${err}`)
    }
}

function apply(path: string) {
    // An empty monitor argument means "all monitors" to the helper.
    execAsync([HELPER, "apply", path, target.get(), fit.get()])
        .then(() => refresh())
        .catch((err) => status.set(`Could not apply wallpaper: ${err}`))
}

// Decoding a 4K image per tile is slow, so scaled thumbnails are cached under
// $XDG_CACHE_HOME keyed by path + mtime; editing an image invalidates its entry.
function thumbnail(path: string): GdkPixbuf.Pixbuf | null {
    try {
        const info = Gio.File.new_for_path(path)
            .query_info("time::modified", Gio.FileQueryInfoFlags.NONE, null)
        const key = GLib.compute_checksum_for_string(
            GLib.ChecksumType.SHA256,
            `${path}:${info.get_attribute_uint64("time::modified")}`,
            -1,
        )
        const dir = `${GLib.get_user_cache_dir()}/hyprveil/wallpaper-thumbs`
        const cached = `${dir}/${key}.png`
        if (GLib.file_test(cached, GLib.FileTest.EXISTS)) {
            return GdkPixbuf.Pixbuf.new_from_file(cached)
        }
        const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, THUMB_W, THUMB_H, true)
        GLib.mkdir_with_parents(dir, 0o700)
        pixbuf.savev(cached, "png", [], [])
        return pixbuf
    } catch (err) {
        // A corrupt or unreadable image must not take the grid down.
        console.error(`wallpaper thumbnail ${path}: ${err}`)
        return null
    }
}

function Tile(path: string, active: boolean) {
    const image = new Gtk.Image({ visible: true })
    // Load off the first frame so opening the grid stays responsive; the tile
    // reserves its size immediately and fills in as decoding finishes.
    image.set_size_request(THUMB_W, THUMB_H)
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
        const pixbuf = thumbnail(path)
        if (pixbuf) image.set_from_pixbuf(pixbuf)
        else image.set_from_icon_name("image-missing", Gtk.IconSize.DIALOG)
        return GLib.SOURCE_REMOVE
    })

    return (
        <button
            className={`wp-tile${active ? " active" : ""}`}
            tooltipText={path}
            onClicked={() => apply(path)}>
            <box vertical>
                {image}
                <label
                    className="wp-tile-name"
                    label={basename(path)}
                    truncate
                    maxWidthChars={20}
                />
            </box>
        </button>
    )
}

function Grid(images: string[], selected: string) {
    const flow = new Gtk.FlowBox({
        visible: true,
        selectionMode: Gtk.SelectionMode.NONE,
        minChildrenPerLine: 3,
        maxChildrenPerLine: 3,
        homogeneous: true,
        rowSpacing: 8,
        columnSpacing: 8,
    })
    for (const path of images) {
        flow.add(Tile(path, path === selected) as unknown as Gtk.Widget)
    }
    flow.show_all()
    return flow
}

// Segmented control: one button per choice, the active one accented.
function Segmented<T extends string>(
    options: Array<{ value: T; label: string }>,
    current: Variable<T>,
    onPick: (value: T) => void,
) {
    return (
        <box className="wp-segmented">
            {options.map(({ value, label }) => (
                <button
                    className={bind(current).as((c) => `wp-segment${c === value ? " active" : ""}`)}
                    onClicked={() => onPick(value)}>
                    <label label={label} />
                </button>
            ))}
        </box>
    )
}

export function openWallpapers() {
    refresh()
    App.get_window(WINDOW)?.set_visible(true)
}

export function closeWallpapers() {
    App.get_window(WINDOW)?.set_visible(false)
}

export function toggleWallpapers() {
    const win = App.get_window(WINDOW)
    if (!win) return
    if (win.visible) win.set_visible(false)
    else openWallpapers()
}

export default function Wallpapers() {
    return (
        <window
            name={WINDOW}
            namespace="hyprveil-wallpapers"
            className="Wallpapers"
            layer={Astal.Layer.TOP}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={false}
            application={App}
            onKeyPressEvent={(self, event) => {
                if (event.get_keyval()[1] === Gdk_KEY_Escape) self.hide()
            }}>
            <box className="wp-panel" vertical>
                <box className="wp-titlebar">
                    <label className="wp-title" label="Wallpapers" xalign={0} hexpand />
                    <button className="wp-close" onClicked={closeWallpapers}>
                        <label label={"\u{f0156}"} />
                    </button>
                </box>

                <box className="wp-controls">
                    {bind(catalog).as((cat) =>
                        Segmented<string>(
                            [
                                { value: "", label: "All monitors" },
                                ...(cat?.outputs ?? []).map((o) => ({ value: o, label: o })),
                            ],
                            target,
                            (value) => {
                                target.set(value)
                                // Show the fit already saved for the new target.
                                const cur = catalog.get()
                                fit.set((value ? cur?.monitors[value] : cur?.fallback)?.fit ?? "cover")
                            },
                        ),
                    )}
                    <box hexpand />
                    {Segmented<Fit>(
                        [
                            { value: "cover", label: "Cover" },
                            { value: "contain", label: "Contain" },
                        ],
                        fit,
                        (value) => fit.set(value),
                    )}
                </box>

                {bind(catalog).as((cat) => {
                    if (!cat) return <label className="wp-empty" label="Loading wallpapers…" />
                    if (cat.images.length === 0) {
                        return (
                            <label
                                className="wp-empty"
                                label={`No supported images in ${cat.dir}\nAdd JPG, PNG, WebP, JXL, or BMP files there.`}
                                justify={Gtk.Justification.CENTER}
                            />
                        )
                    }
                    return (
                        <scrollable
                            className="wp-grid"
                            // GTK CSS has no max-height, and a ScrolledWindow's
                            // minimum size is zero, so the grid is sized here.
                            heightRequest={400}
                            vscroll={Gtk.PolicyType.AUTOMATIC}
                            hscroll={Gtk.PolicyType.NEVER}>
                            {bind(target).as((t) => Grid(cat.images, activePath(cat, t)))}
                        </scrollable>
                    )
                })}

                {bind(status).as((s) =>
                    s ? <label className="wp-status" label={s} wrap /> : <box />,
                )}
            </box>
        </window>
    )
}

// Gdk keyval for Escape (matches QuickSettings).
const Gdk_KEY_Escape = 0xff1b
