# Hyprveil Shell architecture

This document is the contract for the incremental shell migration. It describes
the boundaries that must remain stable while implementation details move.

## Baseline

The reference captures are versioned in `docs/images/`:

| Flow | Evidence |
|---|---|
| Desktop, bar, dock, notifications | `desktop.png` |
| Accent propagation | `desktop-accent.png` |
| Launcher and search | `launcher.png` |
| Wallpaper selection | `wallpaper-picker.png` |
| Full-screen keyboard help | `cheatsheet.png` |

They cover the persistent chrome, modal, popover, and full-screen surface
families. A release capture must replace these files at the same paths so the
README never points at stale assets. `tests/capture-shell.sh` captures the still
set and a short connected-flow demonstration from a running Hyprland session.

Performance is measured by `tests/bench.sh [output.jsonl]`. It records commit,
Quickshell/Qt version, GPU, output count and scale, then samples idle, launcher,
and notification-panel RSS/PSS/USS and CPU. Comparable before/after runs must
use the same machine, output layout, power profile, and five-second idle period.
Opening latency is measured from the CLI request until the coordinator reports
the target surface open; `tests/shell-performance.sh` automates repeated samples.

## Behavioral contract

The migration must preserve these behaviors:

- one bar and dock instance per connected monitor, updated on hotplug;
- one session-wide modal keyboard grab and at most one interactive surface;
- the focused monitor is the default target, with a configured connector able
  to override it;
- `Escape` returns within a surface, then closes it; activation is available by
  keyboard as well as pointer;
- notification history and popups share one daemon and one do-not-disturb state;
- state writes are schema-validated, locked where concurrent writers exist,
  written by atomic rename, and recover malformed input without discarding it;
- wallpaper, pins, notifications, and settings retain their existing persistent
  stores and are exposed to QML through services;
- reduced motion snaps transitions instead of replacing them with slow fades;
- the lock cannot be dismissed through shell IPC. Authentication remains in the
  isolated lock implementation and its fail-safe launcher;
- emergency Rofi and wlogout bindings remain available in recovery mode.

## Runtime layers

```text
shell.qml
  App/Shell.qml
    App/SurfaceCoordinator.qml       one active interactive surface
    App/AnchoredHost.qml             bar-origin popovers
    App/ModalHost.qml                launcher/session/preferences/wallpapers
    App/FullscreenHost.qml           overview/cheatsheet
    App/PassiveHost.qml              OSD/notification presentation
    Features/*                       feature composition and local state
      Design/Components/*            interaction, focus, semantics, visuals
        Design/Tokens.qml + Motion.qml
      Services/*                     normalized observable state
        Adapters/*                   external commands and compositor IPC
```

`shell.qml` is only the Quickshell entry point. `App/Shell.qml` composes the
runtime. Features may call service or adapter methods but must not embed
`systemctl`, `hyprctl`, script paths, or direct settings JSON access.

Lock, passive notifications, and OSD remain separately instantiated because
their security and lifetime differ from interactive navigation. They can consume
read-only shared state but are never children of an interactive modal.

## Surface ownership

| Host | Surfaces | Focus policy |
|---|---|---|
| Anchored | quick settings, calendar, media, tray | restore the opener; use its geometry as transition origin |
| Modal | launcher, session, preferences, wallpapers, integrations | exclusive keyboard focus; fixed outer dimensions |
| Fullscreen | overview, cheatsheet | exclusive on the target output |
| Passive | OSD, notification popups, status capsule | never steals focus |

The coordinator owns `activeSurface`, target screen, origin rectangle, page
history, and focus restoration. Hosts render that state; they do not coordinate
each other. Opening an interactive surface atomically closes the previous one.

## Service contract

Every external-state service exposes `available`, `state`, `busy`, `error`,
`lastUpdated`, `refresh()`, and idempotent actions. An unavailable provider is a
normal state, not a QML exception. Adapters are the only layer allowed to invoke
external commands. This gives features deterministic loading, empty, error, and
unavailable states and gives the CLI one stable entry point.

## Duplicate-pattern baseline

The pre-migration inventory found these repeated constructions:

| Pattern | Previous implementations | Canonical component |
|---|---|---|
| text/icon action | `Panel/Button`, `BarAction`, local Rectangle/Text/MouseArea | `HvButton`, `HvIconButton` |
| boolean switch | `Panel/Toggle`, local switch tracks | `HvToggle` |
| navigable row | `LinkRow`, notification rows, local delegates | `HvListRow`, `HvActionRow` |
| text/search input | launcher and picker text fields | `HvTextField`, `HvSearchField` |
| continuous value | `AudioSlider`, brightness tracks | `HvSlider` |
| surface shell | local panels, scrims, cards | `HvPanel`, `HvDialog`, `HvPopover` |
| section/title/absence | `Section`, local headings and empty labels | `HvSection`, `HvHeader`, `HvEmptyState` |
| focus/help/menu | local border, tooltip, secondary-click menus | `HvFocusRing`, `HvTooltip`, `HvContextMenu` |

Source-level architecture tests prevent features from reintroducing direct
system actions or settings reads. Real QML loading remains the integration gate
when a Wayland session and Quickshell are available.
