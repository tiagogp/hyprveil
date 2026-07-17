# Custom Hyprland Desktop Environment — Fedora, hybrid GPU, multi-monitor

Fresh install, so no backups of existing configs are needed yet — `scripts/00-backup.sh`
still exists and is safe to run any time before you touch `~/.config` again.

The visual target is `design/Hyprland Desktop Design.dc.html` (from the Claude Design
project): dark neutrals, one red accent (#E14658), heavy glass/blur surfaces,
14–16px radii, Geist for UI text, Fira Code for the terminal.

## How this is being delivered (step-by-step, per your preference)

**Stage 1: Hyprland core** ✅
- Centralized color palette (`hypr/colors.conf`)
- Tunable spacing/radius/animation-speed variables (`hypr/variables.conf`)
- Monitor config stub for your multi-monitor + hybrid-GPU desktop (`hypr/monitors.conf`)
- Core `hyprland.conf`, `appearance.conf`, `animations.conf`, `window-rules.conf`,
  `keybindings.conf`, `autostart.conf`
- Fedora package install script for Hyprland itself + hybrid-GPU env vars

**Stage 2 (this delivery): the desktop shell — implements the design mockup** ✅
- **Waybar** (`waybar/`) — two bars from one process: the floating glass top bar
  (workspaces 1–5 left, window title center, wifi/volume/battery/notifications/clock
  right) and an end-4-style bottom dock — a centered pill with launcher, pinned
  apps (kitty/firefox/code/files), and running apps with the accent-red active state
- **Kitty** (`kitty/`) — translucent terminal, Fira Code, full palette mapping
- **Rofi** (`rofi/`) — 480px centered glass launcher with icon rows and accent selection
  (requires `rofi-wayland`)
- **mako** (`mako/`) — glass notification cards, top-right, accent border on critical
- **hyprlock** (`hypr/hyprlock.conf`) — oversized thin clock, accent avatar ring,
  pill password field (design "Lock" screen)
- **wlogout** (`wlogout/`) — Lock/Logout/Suspend/Restart/Shutdown row, Shutdown in
  accent (design "Power" screen)
- **hyprpaper** (`hypr/hyprpaper.conf`) + **hypridle** (`hypr/hypridle.conf`)
- Keybind scheme ported from end-4/dots-hyprland (see cheatsheet below)
- `scripts/02-install-fedora-shell.sh` — packages, Geist + Nerd-symbol fonts, wallpaper

**Coming in later stages** (say "next stage" when ready): screenshot + clipboard
tooling, GTK/Qt theming, cursor/icon themes, zsh + Starship.

## Fedora + Hyprland: what you need to know first

Fedora's official repos don't ship Hyprland directly on most releases yet. The
standard, well-maintained source is the **solopasha/hyprland COPR**. Run:

```bash
sudo dnf copr enable solopasha/hyprland
sudo dnf install hyprland hyprland-devel
```

(`sudo` is required here — dnf/copr always need it. Everywhere else in this project
I've avoided `sudo` unless a step genuinely requires root.)

### Hybrid GPU (dual-GPU desktop)

You flagged your GPU setup as mixed/hybrid. Two sub-cases need different treatment —
tell me which when you get a chance, and I'll tighten `monitors.conf` accordingly:

1. **NVIDIA + Intel/AMD** — needs `WLR_DRM_NO_ATOMIC=1` and rendering pinned to the
   non-NVIDIA GPU in most cases (NVIDIA's Wayland support has sharp edges). Env vars
   are already stubbed in `hypr/variables.conf`, commented out — uncomment if this is you.
2. **AMD + Intel** — works out of the box, no special env vars needed. Leave the
   NVIDIA block commented out.

Run `lspci | grep -E "VGA|3D"` and paste the output back to me so I can lock this down
instead of leaving it as a guess.

## Directory structure

```
config/
├── hypr/
│   ├── hyprland.conf        # entrypoint, sources everything else
│   ├── colors.conf          # single source of truth for the palette
│   ├── variables.conf       # gaps, border width, radius, animation speed — tweak here
│   ├── monitors.conf        # your monitor layout — EDIT before first launch
│   ├── appearance.conf      # general/decoration/blur/shadow, reads colors+variables
│   ├── animations.conf      # bezier curves + animation config
│   ├── window-rules.conf    # floating rules for dialogs/pickers/PiP
│   ├── keybindings.conf     # all binds
│   ├── autostart.conf       # exec-once entries
│   ├── hyprlock.conf        # lock screen (Stage 2)
│   ├── hypridle.conf        # idle -> lock -> dpms -> suspend (Stage 2)
│   └── hyprpaper.conf       # wallpaper (Stage 2)
├── waybar/                  # config.jsonc + style.css (Stage 2)
├── kitty/                   # kitty.conf (Stage 2)
├── rofi/                    # config.rasi + hyprveil.rasi theme (Stage 2)
├── mako/                    # config (Stage 2)
└── wlogout/                 # layout + style.css (Stage 2)
design/
└── Hyprland Desktop Design.dc.html   # the mockup all of this implements
scripts/
├── 00-backup.sh
├── 01-install-fedora-core.sh
└── 02-install-fedora-shell.sh
```

## Install

```bash
chmod +x scripts/*.sh
./scripts/00-backup.sh
./scripts/01-install-fedora-core.sh      # Stage 1: Hyprland core
./scripts/02-install-fedora-shell.sh     # Stage 2: shell packages + fonts + wallpaper
cp -r config/hypr config/waybar config/kitty config/rofi config/mako config/wlogout ~/.config/
```

**Before launching Hyprland:** open `~/.config/hypr/monitors.conf` and replace the
placeholder monitor names/resolutions with your real ones (get them via
`hyprctl monitors` after first login, or `wlr-randr` if available beforehand).

## Reload / restart

```bash
hyprctl reload                 # re-read all Hyprland configs live
pkill waybar; waybar & disown  # restart the bar after editing waybar configs
makoctl reload                 # re-read mako config
```

## Validation checklist

Stage 1:
- [ ] `hyprctl reload` returns no errors
- [ ] `hyprctl monitors` shows all displays at correct resolution/position/scale
- [ ] Window open/close animation is snappy (~180ms), not sluggish
- [ ] Gaps/border radius match `variables.conf` values

Stage 2 (compare against the mockup's five screens):
- [ ] **Desktop**: Waybar floats with rounded corners and blur; active workspace pill
      is red-tinted; active window border is `#E14658`, inactive `#2A2D35`
- [ ] **Dock**: centered pill at the bottom; pinned icons launch apps; running apps
      appear right of the divider with a red-tinted ring on the focused one
- [ ] `SUPER+Return` opens a translucent blurred Kitty with Fira Code
- [ ] **Launcher**: `SUPER+Space` opens the centered 480px rofi panel; selected row
      has the red-tinted background
- [ ] **Notification**: `notify-send "Build complete" "aurora compiled successfully"`
      shows a glass card top-right; `notify-send -u critical` gets the red border
- [ ] **Lock**: `SUPER+L` shows big thin clock, avatar ring, pill password field
- [ ] **Power**: `SUPER+Escape` shows the five-button row with Shutdown in red

## Keybind cheatsheet (end-4 style)

Ported from end-4/dots-hyprland, minus the Quickshell-only widgets (overview,
sidebars, on-screen cheatsheet). `SUPER+Tab` maps to rofi's window switcher
instead of the Quickshell overview.

| Bind | Action |
|---|---|
| tap `SUPER` / `SUPER+Space` | launcher (rofi) |
| `SUPER+Tab` | window switcher |
| `SUPER+Return` / `T` | terminal |
| `SUPER+W` / `C` / `E` | browser / code editor / files |
| `CTRL+SHIFT+Escape` | btop (task manager) |
| `SUPER+V` | clipboard history |
| `SUPER+Period` | emoji picker |
| `Print` / `CTRL+Print` | screenshot → clipboard / + file |
| `SUPER+SHIFT+S` | region snip → clipboard |
| `SUPER+SHIFT+X` | region OCR → clipboard (needs tesseract) |
| `SUPER+SHIFT+C` | color picker |
| `SUPER+minus` / `equal` | screen zoom out / in |
| `SUPER+SHIFT+P` / `N` / `B` / `M` | media play-pause / next / prev / mute |
| `SUPER+Q` | close window (`+SHIFT+ALT` force-kill) |
| `SUPER+ALT+Space` | float/tile toggle |
| `SUPER+F` / `D` | fullscreen / maximize |
| `SUPER+P` | pin window |
| `SUPER+;` / `'` | shrink / grow split |
| `SUPER+number` (`+SHIFT` follow, `+ALT` silent) | workspaces |
| `SUPER+scroll`, `SUPER+CTRL+←/→` | cycle workspaces |
| `SUPER+S` or `SUPER+GRAVE` | scratchpad |
| `SUPER+L` / `SUPER+SHIFT+L` | lock / suspend |
| `SUPER+Escape` or `CTRL+ALT+Delete` | power menu |
| `SUPER+N` | dismiss notifications |

## Customization quick guide

- **Colors** → edit `hypr/colors.conf` for Hyprland; Waybar/Kitty/Rofi/mako/hyprlock/
  wlogout each carry a palette mirror block at the top of their file (these tools
  can't read Hyprland variables — grep for the old hex when changing a color).
- **Gaps / border width / corner radius / animation speed** → `hypr/variables.conf`.
- **Blur strength** → `decoration.blur.size` / `.passes` in `appearance.conf`.
- **Monitor layout** → `hypr/monitors.conf`.
- **Idle/lock timeouts** → `hypr/hypridle.conf`.
- **Wallpaper** → replace `~/.config/hypr/wallpaper.jpg`, then `hyprctl hyprpaper reload ,"~/.config/hypr/wallpaper.jpg"` or restart hyprpaper.
