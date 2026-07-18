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

**Stage 2: the desktop shell — implements the design mockup** ✅
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

**Stage 3 (this delivery): app theming + shell environment** ✅
(screenshot + clipboard tooling originally slated here already landed in Stage 2)
- **GTK** (`gtk-3.0/`, `gtk-4.0/`) — adw-gtk3-dark for GTK3, libadwaita named-color
  overrides in `gtk.css` for both, so every GTK app gets the dark neutrals + red accent
- **Qt** (`qt5ct/`, `qt6ct/`) — Fusion style with a full hyprveil palette
  (`colors/hyprveil.conf`), Geist/Fira Code fonts, Papirus-Dark icons; Hyprland sets
  `QT_QPA_PLATFORMTHEME=qt6ct`
- **Cursor** — Bibata Modern Classic (XCURSOR + HYPRCURSOR env vars in
  `hypr/variables.conf`, installed to `~/.local/share/icons` by script 04)
- **Icons** — Papirus-Dark with folders switched to red via `papirus-folders`
- **`hypr/scripts/apply-theme.sh`** — runs at login (autostart) to push
  theme/cursor/fonts into gsettings, which is the only channel libadwaita apps read
- **zsh** (`zsh/.zshrc`) — shared history, menu completion, autosuggestions +
  syntax highlighting (Fedora packages), history search on arrow keys
- **Starship** (`starship.toml`) — minimal two-line prompt, accent-red directory
  and `❯`, git branch/status in muted gray
- `scripts/04-install-fedora-theming.sh` — packages, Bibata, papirus-folders,
  Qt config install (expands `__HOME__` placeholders), `~/.zshrc` + `chsh`

That completes the original roadmap.

**Stage 4 (extra): SDDM login-screen theming** ✅
- **SDDM** (`sddm/hyprveil/`) — QML greeter theme matching hyprlock's idiom:
  oversized thin clock, accent avatar ring + username (`userModel`-bound),
  pill password field, and a Suspend/Restart/Shutdown row styled after the
  design mockup's Power screen (reuses wlogout's installed icons so the two
  match pixel-for-pixel). Bundles its own Geist fonts since the greeter runs
  as the `sddm` system user, which can't see `~/.local/share/fonts`.
- Uses SDDM's own Wayland (Weston-backed) greeter by default — Fedora's real
  compiled-in default, not the "experimental" X11 fallback older docs
  describe — with an X11-greeter opt-out for the NVIDIA hybrid-GPU case (see
  "Hybrid GPU" below).
- `scripts/06-install-fedora-sddm.sh` — the one piece of hyprveil that changes
  a *system* file (`/etc/sddm.conf.d/`) and replaces the machine's display
  manager for every login, so every step inside it is separately confirmed.
  `scripts/05-install-all.sh` offers to run it as a final, separately-gated
  step; it's also runnable standalone. Test the theme with zero system
  changes first: `sddm-greeter-qt6 --test-mode --theme config/sddm/hyprveil`.

Remaining possible extras if you want them later: per-app GTK tweaks, kitty
tab/session tooling.

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

This same NVIDIA-hybrid question resurfaces in `scripts/06-install-fedora-sddm.sh`:
SDDM's Wayland/Weston greeter has an open upstream GPU-handoff issue on NVIDIA
hybrid setups ([sddm#2142](https://github.com/sddm/sddm/issues/2142)), so that
script asks the same question and installs `sddm-x11` instead of
`sddm-wayland-generic` when you say yes. AMD+Intel/single-GPU is unaffected.

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
│   ├── hyprpaper.conf       # wallpaper (Stage 2)
│   └── scripts/             # zoom.sh, apply-theme.sh (gsettings push, Stage 3)
├── waybar/                  # config.jsonc + style.css (Stage 2)
├── kitty/                   # kitty.conf (Stage 2)
├── rofi/                    # config.rasi + hyprveil.rasi theme (Stage 2)
├── mako/                    # config (Stage 2)
├── wlogout/                 # layout + style.css (Stage 2)
├── gtk-3.0/                 # settings.ini + accent gtk.css (Stage 3)
├── gtk-4.0/                 # settings.ini + libadwaita accent gtk.css (Stage 3)
├── qt5ct/                   # qt5ct.conf + colors/hyprveil.conf (Stage 3)
├── qt6ct/                   # qt6ct.conf + colors/hyprveil.conf (Stage 3)
├── zsh/                     # .zshrc — script 04 copies it to ~/.zshrc (Stage 3)
├── starship.toml            # prompt theme (Stage 3)
└── sddm/hyprveil/           # SDDM QML greeter theme (Stage 4, extra) — a
    ├── metadata.desktop     #   *system* install (/usr/share/sddm/themes/),
    ├── theme.conf           #   not copied via ~/.config like everything else
    ├── Main.qml
    └── Components/          # Palette.qml, Clock.qml, UserAvatar.qml,
                              # PasswordField.qml, SessionPicker.qml, PowerRow.qml
design/
└── Hyprland Desktop Design.dc.html   # the mockup all of this implements
scripts/
├── 00-backup.sh
├── 01-install-fedora-core.sh
├── 02-install-fedora-shell.sh
├── 03-test-config.sh
├── 04-install-fedora-theming.sh
└── 06-install-fedora-sddm.sh   # Stage 4 (extra) — its own gated steps; 05 offers
                                 # to run it as a final, separately-confirmed step
```

## Install

```bash
chmod +x scripts/*.sh
./scripts/00-backup.sh
./scripts/01-install-fedora-core.sh      # Stage 1: Hyprland core
./scripts/02-install-fedora-shell.sh     # Stage 2: shell packages + fonts + wallpaper
./scripts/04-install-fedora-theming.sh   # Stage 3: GTK/Qt/cursor/icons + zsh/Starship
./scripts/03-test-config.sh              # test BEFORE installing (see below) — offers
                                          # to install for real once the nested test looks right
```

Script 04 handles the pieces the config copy can't: the qt5ct/qt6ct configs (their
`color_scheme_path` needs your absolute home dir — the repo files carry a
`__HOME__` placeholder it expands) and `~/.zshrc` + `chsh` (zsh reads from
`$HOME`, not `~/.config`).

### Optional: SDDM login screen

`scripts/05-install-all.sh` above ends by offering to run this too, as its
own separately-confirmed final step. To run it standalone instead (e.g. later,
after everything else is verified working) — it's the one piece of hyprveil
that touches system files (`/usr/share/sddm/`, `/etc/sddm.conf.d/`) and can
replace your display manager:

```bash
./scripts/06-install-fedora-sddm.sh
```

It previews the theme in a window first (`sddm-greeter-qt6 --test-mode`, no
root, no system changes) before asking to install `sddm`, copy the theme,
point sddm at it, and — as a separately confirmed last step — actually enable
`sddm.service` in place of your current display manager.

## Test before use — `scripts/03-test-config.sh`

Run it from the repo root any time. Phases 1 and 2 never touch `~/.config`:

1. **Static checks** (run anywhere): all config files present, waybar/wlogout JSON
   valid, every command the binds call is installed, fonts installed, and — if your
   Hyprland build supports it — a full `Hyprland --verify-config` parse check.
2. **Nested live test** (when run from inside any Wayland session, including your
   current end-4 desktop): boots hyprveil **in a window** from a staged copy of the
   repo's configs (`XDG_CONFIG_HOME` points at the stage, so waybar/rofi/mako/kitty
   inside it read repo configs, not your real ones). Exit with `SUPER+SHIFT+Q`.
3. **Install prompt**: after the nested session exits, the script asks whether it
   looked right and, if you say yes, runs the `cp -r config/...` copy into
   `~/.config` for you. Say no (or skip phase 2 entirely) to leave `~/.config`
   untouched and copy manually later.

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
- [x] `hyprctl reload` returns no errors
- [x] `hyprctl monitors` shows all displays at correct resolution/position/scale
- [x] Window open/close animation is snappy (~180ms), not sluggish
- [x] Gaps/border radius match `variables.conf` values

Stage 2 (compare against the mockup's five screens):
- [x] **Desktop**: Waybar floats with rounded corners and blur; active workspace pill
      is red-tinted; active window border is `#E14658`, inactive `#2A2D35`
- [x] **Dock**: centered pill at the bottom; pinned icons launch apps; running apps
      appear right of the divider with a red-tinted ring on the focused one
- [x] `SUPER+Return` opens a translucent blurred Kitty with Fira Code
- [x] **Launcher**: `SUPER+Space` opens the centered 480px rofi panel; selected row
      has the red-tinted background
- [x] **Notification**: `notify-send "Build complete" "aurora compiled successfully"`
      shows a glass card top-right; `notify-send -u critical` gets the red border
- [x] **Lock**: `SUPER+L` shows big thin clock, avatar ring, pill password field
- [x] **Power**: `SUPER+Escape` shows the five-button row with Shutdown in red

Stage 3 (after script 04 + config copy + logout/login):
- [x] Cursor is Bibata (black, rounded) everywhere, including over app windows
- [x] GTK app (e.g. nautilus): dark surfaces, **red** selection/accent instead of
      blue, red folder icons, Geist as UI font
- [x] Qt app (e.g. pavucontrol if Qt, or run `qt6ct` itself): dark Fusion palette
      with red highlight — open qt6ct and check the preview
- [x] New Kitty window drops you in zsh with the Starship prompt: red directory,
      red `❯`, git branch shown inside a repo
- [x] Typing shows gray ghost autosuggestions; invalid commands render red
      (syntax highlighting)

Stage 4 (extra, after `scripts/06-install-fedora-sddm.sh`):
- [x] `sddm-greeter-qt6 --test-mode --theme config/sddm/hyprveil` shows the
      clock/avatar/password-pill matching hyprlock's look — check this
      *before* enabling sddm as the display manager
- [x] After enabling sddm + reboot: Geist renders correctly in the greeter
      (catches a stale/missing `Fonts/` bundle)
- [x] Hyprland is selectable in the session picker
- [x] Suspend/Restart/Shutdown all work, Shutdown shown in accent red

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
  Stage 3 mirrors: `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`,
  `qt5ct/colors/hyprveil.conf`, `qt6ct/colors/hyprveil.conf`, `starship.toml`.
  Stage 4 mirror: `sddm/hyprveil/Components/Palette.qml` (also hardcoded, same
  "can't read Hyprland variables — keep in sync manually" caveat as hyprlock);
  re-run step 2 of `scripts/06-install-fedora-sddm.sh` after editing it to
  copy the change into `/usr/share/sddm/themes/hyprveil`.
- **Gaps / border width / corner radius / animation speed** → `hypr/variables.conf`.
- **Blur strength** → `decoration.blur.size` / `.passes` in `appearance.conf`.
- **Monitor layout** → `hypr/monitors.conf`.
- **Idle/lock timeouts** → `hypr/hypridle.conf`.
- **Wallpaper** → replace `~/.config/hypr/wallpaper.jpg`, then `hyprctl hyprpaper reload ,"~/.config/hypr/wallpaper.jpg"` or restart hyprpaper.
- **Cursor theme/size** → env vars in `hypr/variables.conf` **and**
  `hypr/scripts/apply-theme.sh` (keep both in sync), then `hyprctl reload` and
  re-run the script.
- **GTK/Qt/icon/font choices** → `hypr/scripts/apply-theme.sh` (gsettings, wins for
  libadwaita apps) plus the matching `gtk-*/settings.ini` / `qt6ct.conf`.
- **Folder accent color** → `sudo papirus-folders -C <color> --theme Papirus-Dark`.
- **Prompt** → `starship.toml` (`starship explain` helps); zsh behavior → `~/.zshrc`
  (repo copy: `config/zsh/.zshrc` — re-run the script 04 zsh step after editing).
