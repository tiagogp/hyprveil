# Hyprveil roadmap

Hyprveil is evolving from a personal Fedora Hyprland setup into a reusable,
well-tested template. This roadmap covers the rolling current and previous stable
Fedora releases. It does not imply that planned features are already available.

## Status legend

- **Existing** — already present in the repository and used as the baseline.
- **Planned** — agreed work that has not been implemented yet.
- **In progress** — implementation has started but its acceptance checklist is not complete.
- **Complete** — implemented, documented, and verified against the milestone checklist.

## Current baseline

The repository already provides a staged Fedora installer, a modular Hyprland
configuration, Waybar top and bottom bars, an application launcher, a SwayNC
notification center with a Mako fallback, Hyprpaper, theming, lock and power screens, and an optional SDDM
theme. The bottom dock already supports right-click pinning persisted under
`$XDG_STATE_HOME/hyprveil`; the roadmap improves its launch resolution,
management, and discoverability.

## P0 — Fedora template foundation

**Status:** In progress  
**Priority:** P0  
**Depends on:** Current installer and validation scripts

### Deliverables

- Define a rolling support policy for the current and previous stable Fedora
  releases, recording the versions exercised for each tagged Hyprveil release.
- Detect the Fedora release from `/etc/os-release` and probe enabled repositories
  before selecting a package source.
- Prefer Fedora's official packages. Offer a COPR only when a required package is
  unavailable, explain why it is needed, and require explicit confirmation before
  enabling it.
- Make every install stage safe to rerun. Preserve existing configuration and
  persistent state, create a timestamped backup before replacement, and avoid
  accumulating stale files.
- Add selectable desktop/laptop and Intel/AMD/NVIDIA hardware profiles without
  silently enabling vendor-specific environment variables.
- Report required, optional, and unavailable dependencies before copying configs.
- Replace release-sensitive setup claims with repository detection and links to
  current package information.

### Acceptance checklist

- [ ] A clean install succeeds on both supported Fedora releases.
- [x] Repeating the installer does not duplicate repositories, overwrite state, or
      change a selected hardware profile.
- [x] Declining a COPR leaves the system unchanged and reports only the affected
      optional feature as unavailable.
- [x] Desktop and laptop profiles handle absent battery and brightness hardware.
- [x] Intel, AMD, and NVIDIA paths are documented and no GPU-specific workaround is
      enabled by default.
- [x] The validation script reports the Fedora version, chosen package sources, and
      actionable dependency failures.

The P0 implementation and mocked rerun/refusal/profile checks have landed. The
milestone remains in progress until clean VM installs are recorded for Fedora 44 and
43 in `docs/SUPPORT.md`; a mocked check is not a substitute for that release gate.

## P1 — Top bar and dock

**Status:** Complete  
**Priority:** P1  
**Depends on:** P0 dependency detection; Waybar, BlueZ/Blueman, Playerctl, Rofi, Jq

### Deliverables

- Add Waybar's Bluetooth module with disabled, enabled, connected, and unavailable
  states. Its tooltip will show connected device names and available battery data;
  left-click will open `blueman-manager`.
- Hide Bluetooth cleanly when no controller exists and keep the rest of Waybar
  operational when Blueman is not installed.
- Add an any-player MPRIS area containing a truncated `artist — title` label and
  visible previous, play/pause, and next controls.
- Select the first playing MPRIS player, fall back to a paused player, and hide the
  entire media area when no player is available. Escape metadata before returning
  Waybar JSON.
- Expose a media helper with `render`, `previous`, `toggle`, and `next` commands.
- Retain the dock's atomic, locked state file and right-click pin toggle. Add a Rofi
  manager exposing `list`, `add`, `remove`, and `move` actions for up to ten pins.
- Populate the manager from installed `.desktop` entries and launch pinned apps
  through their desktop entry rather than assuming a window class is executable.
- Preserve user pin order during upgrades and show a clear message when the ten-pin
  limit is reached.

### Acceptance checklist

- [x] Bluetooth renders the correct state with zero, one, and multiple connected
      devices, and Waybar still starts without a Bluetooth adapter.
- [x] Clicking Bluetooth opens Blueman when installed and fails visibly but safely
      when it is missing.
- [x] Spotify, a browser, and VLC can each supply media metadata and controls.
- [x] A playing player wins over paused players; no-player and stale-player states
      leave an empty media area without polling errors.
- [x] Long or markup-containing titles are safely escaped and truncated.
- [x] Dock pins can be added, removed, reordered, focused, launched, and closed.
- [x] Flatpak and Electron applications launch from their `.desktop` entries, and a
      malformed pin file is backed up and recovered without damaging other state.

P1 is covered by `tests/p1-smoke.sh`, which mocks adapter/device combinations,
Blueman availability, Spotify/browser/VLC MPRIS names, stale players, Hyprland
clients, desktop-entry launching, the pin limit, and malformed-state recovery.

## P2 — Notification center

**Status:** Complete  
**Priority:** P2  
**Depends on:** P0 repository prompts; SwayNotificationCenter COPR

### Deliverables

- Replace Mako as the default notification daemon with a SwayNC configuration and
  CSS matching Hyprveil's glass surfaces, spacing, typography, and accent colors.
- Provide popup notifications plus a control center with history, clear-all, and a
  persistent do-not-disturb toggle.
- Drive the Waybar notification icon with `swaync-client -swb`: left-click toggles
  the center and right-click toggles do-not-disturb.
- Change `SUPER+N` to toggle the control center. Keep clear-all and DND accessible
  from the panel rather than binding a destructive dismiss action to the same key.
- Remove Mako from the default package, startup, copy, reload, and validation paths
  so both notification daemons can never autostart together.
- Keep Mako as a documented fallback profile for users who decline the SwayNC COPR;
  selecting a backend must update startup and Waybar actions consistently.

### Acceptance checklist

- [x] Normal, low, and critical notifications have the intended popup treatment.
- [x] Notifications remain in history, clear-all works, and DND persists across a
      session restart.
- [x] The Waybar icon reflects empty, populated, DND, and inhibited states.
- [x] Inline actions and notification dismissal work with mouse and keyboard.
- [x] Selecting SwayNC or the Mako fallback results in exactly one running daemon.
- [x] Declining the SwayNC COPR preserves the working Mako fallback and is explained
      by the installer.

P2 is covered by `tests/p2-smoke.sh`, which validates the SwayNC JSON and urgency
styles, all Waybar state icons and actions, persistent backend selection, exclusive
daemon startup, selected-only deployment, and the Mako DND fallback.

## P3 — Wallpaper customization and motion

**Status:** Complete  
**Priority:** P3  
**Depends on:** Hyprpaper, Hyprctl, Rofi, Jq; P0 state and validation conventions

### Deliverables

- Add a Rofi wallpaper picker that scans `~/Pictures/Wallpapers` for supported image
  files, then asks for all monitors or one currently connected monitor and for
  `cover` or `contain` mode.
- Expose wallpaper helper commands `pick`, `apply`, and `restore`. `apply` accepts a
  wallpaper path plus optional monitor and fit mode.
- Persist the fallback wallpaper, per-monitor mappings, and fit modes in
  `$XDG_STATE_HOME/hyprveil/wallpapers.json`; write the file atomically.
- Restore valid selections after Hyprpaper starts. Ignore mappings for disconnected
  monitors, retain them for later reconnection, and fall back to the bundled default
  when a selected file disappears.
- Detect supported Hyprpaper IPC at runtime and use the modern `wallpaper` request or
  the legacy preload/reload flow as appropriate for the supported Fedora releases.
- Bind `SUPER+SHIFT+W` to the picker.
- Split Hyprland motion into `standard` and `reduced` profiles. Standard adds
  restrained window, workspace, layer, and special-workspace motion; reduced uses
  short fades and minimal spatial movement.
- Add a motion selector accepting `standard` or `reduced`, persist the choice, and
  safely reload Hyprland after switching.

### Acceptance checklist

- [x] The picker handles an empty wallpaper directory and filenames containing
      spaces, quotes, and non-ASCII characters.
- [x] One wallpaper can target all monitors or a selected monitor in either fit mode.
- [x] Choices survive logout/login and disconnected monitor mappings survive until
      that monitor returns.
- [x] Missing files and malformed state fall back safely without preventing login.
- [x] Wallpaper application works with both supported Hyprpaper IPC variants.
- [x] Standard and reduced motion profiles parse, reload, persist, and remain usable
      with animations globally disabled.

P3 is covered by `tests/p3-smoke.sh`, which mocks current and legacy Hyprpaper IPC,
connected and disconnected outputs, missing and malformed state, special-character
picker entries, persistent motion selection, and reload rollback.

## P4 — Quality and template release

**Status:** In progress  
**Priority:** P4  
**Depends on:** P0–P3

### Deliverables

- Extend static and nested-session validation for Bluetooth, media, notification
  backend selection, dock state, wallpaper restoration, and both motion profiles.
- Add ShellCheck, JSON/JSONC parsing, executable-bit checks, and mocked command tests
  for scripts that consume `hyprctl`, `playerctl`, desktop entries, or persistent
  state.
- Maintain a manual VM test matrix for the current and previous stable Fedora
  releases, covering fresh install, rerun, upgrade, COPR refusal, and fallback paths.
- Document configuration, optional dependencies, hardware profiles, recovery,
  keybindings, state locations, upgrades, and rollback.
- Define a release checklist and require every earlier acceptance checklist to pass
  before calling the repository a reusable Fedora template.

### Acceptance checklist

- [x] Static validation and mocked tests pass without a running Hyprland session.
- [x] Nested-session checks exercise the shell without modifying real user config.
- [ ] Manual VM results are recorded for both supported Fedora releases.
- [x] Fresh install, rerun, and upgrade preserve user pins, wallpapers, motion choice,
      and notification backend.
- [x] Documentation contains recovery steps for a broken bar, wallpaper daemon,
      notification daemon, and Hyprland configuration.
- [x] No milestone is marked complete until its deliverables, tests, and user-facing
      documentation have landed.

P4 adds `tests/run.sh`, CI enforcement, an isolated nested-session launcher and
smoke test, the manual Fedora VM matrix, release gate, configuration/state guide,
and component recovery/rollback guide. Automated checks cover preservation across
clean deployment and mocked upgrades. The milestone remains in progress until the
Fedora 44 and 43 VM rows in `docs/VM-TEST-MATRIX.md` are completed; the release
checklist intentionally forbids a template tag while those results are pending.

## P5 — Unified quick-settings panel

**Status:** In progress
**Priority:** P5
**Depends on:** P0 COPR consent + dependency detection; P2 notification-backend abstraction; AGS v2 / Astal, NetworkManager, BlueZ

### Deliverables

- Add a glass **quick-settings panel** built with AGS v2 / Astal (TypeScript, GTK
  layer-shell) that unifies **Wi-Fi**, **Bluetooth**, and **notifications** in one
  surface matching Hyprveil's design system.
- Make AGS the default notification backend via `AstalNotifd` (popups, history,
  clear-all, persistent DND), retiring SwayNC and Mako to selectable fallbacks; only
  one daemon ever runs.
- Wi-Fi section (`AstalNetwork`): toggle, rescan, signal-sorted network list, connect
  (secured joins via the NetworkManager secret agent), with an advanced-settings
  escape hatch.
- Bluetooth section (`AstalBluetooth`): adapter power toggle, device list with
  connect/disconnect and battery percentage, with a Blueman escape hatch.
- Toggle the panel from `SUPER+N` and the Waybar Wi-Fi/Bluetooth/notification icons;
  fall back to the external managers when AGS is not the active backend.
- Add a **wallpaper grid**: thumbnails of `~/Pictures/Wallpapers` with monitor and
  cover/contain controls, marking the selection that would be restored. It renders
  `wallpaper.sh list` and applies through `wallpaper.sh apply`, so the P3 state
  schema, atomic writes, and Hyprpaper IPC detection stay in one place. `SUPER+SHIFT+W`
  opens the grid when the shell is running and the Rofi flow otherwise.
- Install AGS + Astal from the `solopasha/hyprland` COPR behind the existing consent
  prompt; declining preserves the SwayNC/Mako notification path.
- Give the panel and popups glass blur via Hyprland layer rules.

### Acceptance checklist

- [x] Backend selection accepts `ags` (default), `swaync`, and `mako`; exactly one
      daemon runs after a switch.
- [x] The Waybar notification icon reflects the AGS count/DND status; toggle and DND
      route through the AGS request bridge.
- [x] Declining the AGS and SwayNC COPRs leaves repositories unchanged and selects the
      Mako fallback.
- [x] Deployment installs only the selected backend tree and backs up the inactive
      ones; the AGS config deploys under `~/.config/ags`.
- [x] Panel toggle, layer blur rules, and backend-aware autostart are wired.
- [x] The wallpaper grid lists, applies, and marks per-monitor and all-monitor
      selections through the shared helper; `SUPER+SHIFT+W` falls back to Rofi when
      the shell is not running.
- [ ] A live session confirms Wi-Fi scan/connect/toggle, Bluetooth power/connect/
      battery, and notification popup/history/DND on both supported Fedora releases.

P5 is covered by `tests/p5-smoke.sh`, which validates the AGS project structure and
request handlers, `ags` backend selection and daemon exclusivity, the Waybar status
bridge, the Hyprland/Waybar integration wiring, the layer blur rules, the stylesheet's
Sass compatibility, and selected-only deployment. The wallpaper grid's helper contract
(`list` output and AGS-versus-Rofi routing) is covered by `tests/p3-smoke.sh`
alongside the state and IPC behavior it reuses. The
milestone remains in progress until the live-session row is recorded in
`docs/VM-TEST-MATRIX.md`.

## Planned interfaces and state

| Component | Interface | Persistent state |
|---|---|---|
| Notification backend | `--backend ags\|swaync\|mako`, `--ensure` | `$XDG_STATE_HOME/hyprveil/notification-backend` |
| Quick-settings panel | `ags request toggle-quicksettings\|notif-status\|notif-dnd\|notif-clear\|toggle-wallpapers` | None (live AstalNetwork/Bluetooth/Notifd state) |
| Dock manager | `list`, `add`, `remove`, `move` | `$XDG_STATE_HOME/hyprveil/dock-pins.json` |
| Media helper | `render`, `previous`, `toggle`, `next` | None |
| Wallpaper helper | `pick`, `apply`, `list`, `restore` | `$XDG_STATE_HOME/hyprveil/wallpapers.json` |
| Motion selector | `standard`, `reduced` | `$XDG_STATE_HOME/hyprveil/motion-profile` |

State files must be schema-checked, written atomically, and recover from malformed
content by preserving the bad file for diagnosis and restoring safe defaults.

## References

- [Fedora Packages](https://packages.fedoraproject.org/)
- [Waybar](https://github.com/Alexays/Waybar)
- [SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter)
- [Hyprpaper](https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/)
- [AGS (Aylur's GTK Shell)](https://aylur.github.io/ags/) and [Astal](https://aylur.github.io/astal/)
- [`solopasha/hyprland` COPR](https://copr.fedorainfracloud.org/coprs/solopasha/hyprland/)
