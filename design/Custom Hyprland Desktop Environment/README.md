# Custom Hyprland Desktop Environment — Fedora, hybrid GPU, multi-monitor

Fresh install, so no backups of existing configs are needed yet — `scripts/00-backup.sh`
still exists and is safe to run any time before you touch `~/.config` again.

## How this is being delivered (step-by-step, per your preference)

**Stage 1 (this delivery): Hyprland core**
- Centralized color palette (`hypr/colors.conf`)
- Tunable spacing/radius/animation-speed variables (`hypr/variables.conf`)
- Monitor config stub for your multi-monitor + hybrid-GPU desktop (`hypr/monitors.conf`)
- Core `hyprland.conf`, `appearance.conf`, `animations.conf`, `window-rules.conf`,
  `keybindings.conf`, `autostart.conf`
- Fedora package install script for Hyprland itself + hybrid-GPU env vars

**Coming in later stages** (say "next stage" when ready): Waybar, Kitty, Rofi/Wofi,
mako notifications, hyprlock, hypridle, hyprpaper/wallpaper, screenshot + clipboard
tooling, GTK/Qt theming, cursor/icon themes, fonts, zsh + Starship.

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

## Directory structure (this stage)

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
│   └── autostart.conf       # exec-once entries (grows in later stages)
scripts/
├── 00-backup.sh
└── 01-install-fedora-core.sh
```

## Install (Stage 1)

```bash
chmod +x scripts/*.sh
./scripts/00-backup.sh
./scripts/01-install-fedora-core.sh
mkdir -p ~/.config/hypr
cp config/hypr/*.conf ~/.config/hypr/
```

**Before launching Hyprland:** open `~/.config/hypr/monitors.conf` and replace the
placeholder monitor names/resolutions with your real ones (get them via
`hyprctl monitors` after first login, or `wlr-randr` if available beforehand).

## Reload / restart (Stage 1 scope)

```bash
hyprctl reload                 # re-read all Hyprland configs live, no restart needed
```

## Validation checklist (Stage 1)

- [ ] `hyprctl reload` returns no errors
- [ ] `hyprctl monitors` shows all displays at correct resolution/position/scale
- [ ] Window open/close animation is snappy (~180ms), not sluggish
- [ ] `SUPER+Return` opens Kitty (once Stage 3 is applied — for now it'll error, that's expected)
- [ ] Gaps/border radius match `variables.conf` values
- [ ] Floating rules apply to file pickers / pavucontrol once those apps are installed

## Customization quick guide

- **Colors** → edit `hypr/colors.conf` only; every other file references its `$variables`.
- **Gaps / border width / corner radius / animation speed** → `hypr/variables.conf`.
- **Blur strength** → `decoration.blur.size` / `.passes` in `appearance.conf`.
- **Monitor layout** → `hypr/monitors.conf`.
