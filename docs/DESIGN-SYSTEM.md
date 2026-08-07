# Hyprveil design system

Hyprveil is a calm, dense desktop shell. Its visual identity comes from shared
geometry, restrained elevation, readable state, and transitions that explain
where content came from. It does not depend on constant morphing.

## Foundations

`config/quickshell/Tokens.qml` is generated from `config/hypr/tokens.conf` and
is the source for spacing, radii, type, elevation, color, and durations.
`Accent.qml` supplies the wallpaper-derived accent family. `Surface.qml`
combines fill, hairline and shadow into one elevation choice. Components must
consume these APIs rather than copy literal design values.

### Density and geometry

- All layout follows the 4 px grid. `spacing1h` and `spacing2h` are permitted
  only as internal control padding.
- Pointer and keyboard action targets are at least `iconHit` (40 px).
- Compact rows are 40 px, standard rows 48 px, and modal primary actions 56 px.
- Nested radii descend from panel (`radiusLg`) through cards (`radiusMd`) and
  controls (`radiusSm`) to small indicators (`radiusXs`).
- Modal outer size stays fixed while pages change; content scrolls internally.

### Typography

- JetBrains Mono is the UI and icon-support family; IBM Plex Mono is reserved
  for code or machine values.
- `textMd` is default body size, `textSm` metadata, `textLg` section titles, and
  `textXl` modal titles. Body copy uses regular weight; labels use medium;
  headings use semibold. Bold is reserved for exceptional emphasis.
- Muted text must keep 4.5:1 contrast over the worst supported surface. `dim`
  is only for nonessential ornament or metadata.

### Elevation

| Tier | Use |
|---|---|
| 0 | persistent bar/dock and flat panel body |
| 1 | card or raised selection |
| 2 | dialog/popover window |
| 3 | transient overlay requiring separation |

Use `Surface.elevation`; never choose opacity, border, and shadow separately.
Bar and dock may use the measured chrome alpha override because they do not host
paragraph text.

## Interaction states

Every action component implements the same state order:

1. disabled/unavailable;
2. busy;
3. pressed;
4. focused;
5. hovered;
6. normal.

Hover raises the neutral surface; press reduces scale slightly; keyboard focus
adds the accent `HvFocusRing` without moving layout. Disabled controls retain
their label but use muted opacity and expose an unavailable accessible state.
Busy actions reject repeat activation unless the action is explicitly safe to
coalesce. Pointer, Enter, Space, and the component's declared mnemonic trigger
the same signal.

## Navigation and accessibility

- Tab/Backtab traverses controls in visual order. Arrow keys move within lists,
  grids, sliders, and segmented choices. Enter activates. Escape goes back or
  closes the current surface.
- Every actionable control supplies an accessible role, name, description when
  the label is insufficient, focusability, and checked/value state as relevant.
- Icon-only actions always have an accessible name and tooltip.
- Focus rings are drawn outside the content and remain visible at fractional
  scale. Color is never the sole state indicator.
- Reduced motion produces immediate state changes. No required information is
  conveyed only by animation.

## Shared surface anatomy

Interactive surfaces use the same vertical structure: `HvHeader`, optional
summary, page content, and optional action footer. `HvHeader` owns title, back,
close, and stable height. `HvSection` owns label and content spacing.

Detail progresses from summary to section to advanced configuration. A row that
opens detail uses `HvActionRow` and preserves the surrounding panel geometry.
Loading, empty, error, and unavailable content uses `HvEmptyState` with a stable
icon/title/detail/action arrangement; components do not invent one-line error
labels.

## Motion

- Entry and exit use the origin provided by `SurfaceCoordinator`: anchored
  surfaces scale/fade from the opener; modal and full-screen surfaces use a
  short translate/fade.
- Page changes share `Motion.duration(Tokens.dur2h)` and `Tokens.easeOut`.
- Exit is never longer than entry. Repeated controls do not stagger.
- Bar and dock reveal/hide on the same motion scale and share surface, border,
  and focus treatment with the rest of the shell.

## Component policy

Feature modules compose controls from `Design/Components`. A raw `Rectangle`
is appropriate for layout, decorative geometry, thumbnails, or graphs, but not
as an ad hoc button paired with `Text` and `MouseArea`. New interaction behavior
belongs in a shared component first, including focus and accessibility.
