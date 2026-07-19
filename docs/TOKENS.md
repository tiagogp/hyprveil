# Design tokens

Every non-color value in Hyprveil — radius, spacing, type, elevation, motion —
comes from `config/hypr/tokens.conf`. Colors live next door in `colors.conf`, and
the accent is derived from the wallpaper (see [ACCENT.md](ACCENT.md)).

The problem this solves is that the desktop is assembled from six config formats
that share no variable system. Hyprland has `$vars`, GTK CSS has `@define-color`
but no length variables, QML has properties, and mako has neither. Before tokens,
a 14px card corner existed as the literal `14` in five files, and it had already
drifted to 8, 9, 11, and 12 in four of them.

## How a token reaches a component

Two mechanisms, chosen by what the target can read:

**Sourced directly.** Hyprland and hyprlock read `tokens.conf` natively:

```
source = ~/.config/hypr/tokens.conf
...
rounding = $radius-sm
```

**Rendered from a template.** Everything else gets its values baked in by
`hypr/scripts/theme.sh`, which expands `@name@` placeholders in a `.in` template:

| Template | Output |
|---|---|
| `quickshell/Tokens.qml.in` | `quickshell/Tokens.qml` |
| `wlogout/style.css.in` | `wlogout/style.css` |
| `swaync/style.css.in` | `swaync/style.css` |
| `mako/config.in` | `mako/config` — owned by `accent.sh`, see below |

Generated files are committed. An unrendered checkout has to look identical to a
deployed one, or a fresh clone shows a half-themed desktop.

After editing `tokens.conf` or any `.in` template:

```sh
~/.config/hypr/scripts/theme.sh render
```

`tests/p7-token-smoke.sh` fails if a committed output is stale, so a template
edit without a render does not ship.

### Values are stored unitless

The same `10` has to reach Hyprland as `10`, CSS as `10px`, and QML as `10`. The
unit belongs to the renderer, not the token, so `tokens.conf` never contains one
— the guard test rejects `px`, `pt`, `em`, `ms`, and `%`.

`theme.sh` therefore offers each token in several forms:

| Placeholder | Expands to | For |
|---|---|---|
| `@radius-md@` | `14` | Hyprland, QML, mako |
| `@radius-md-px@` | `14px` | GTK CSS |
| `@dur-2-ms@` | `150ms` | CSS transitions |
| `@ease-standard-points@` | `0.25, 0.1, 0.25, 1` | Hyprland `bezier =`, QML `bezierCurve` |
| `@ease-standard@` | `cubic-bezier(0.25, 0.1, 0.25, 1)` | CSS |

The `-px` and `-ms` variants are generated for every numeric token, not from a
list of which token needs which unit — that list would be a second table that
drifts from the first. An unused placeholder costs one sed clause and is never
written anywhere.

### Who owns which file

`render-lib.sh` holds one invariant: **no output file has two writers.** A
template rendered twice would have each pass drop the other's placeholders,
because rendering always starts from the template.

- `theme.sh` owns the token-only consumers (Quickshell, wlogout, swaync).
- `accent.sh` owns every template that carries the accent *as well as* tokens —
  `mako/config`, the Qt palettes, the wlogout icon SVGs. It loads the design
  tokens too, so those files get both.
- `theme.sh render` calls `accent.sh render` at the end so a token change still
  reaches the accent-owned files. `write_if_changed` makes that a no-op when
  nothing moved.

`gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` are deliberately **not** templated: they
carry named colors and not one length, so a template would add a generated file
that never changes.

---

## The scales

### Radius — 6 / 10 / 14 / 18 / 999

A 4px ramp whose step equals `$space-1`. That is what makes nesting concentric
by construction: a `$radius-md` card inset by `$space-1` inside a `$radius-lg`
panel has corners parallel to its parent, because 18 − 4 = 14.

Four steps is exactly the nesting depth the UI has:

```
panel ($radius-lg) > card ($radius-md) > control ($radius-sm) > chip ($radius-xs)
```

`$radius-pill` (999) is not a step — it is the "fully round" sentinel for
switches, close buttons, and scrollbar sliders.

### Spacing — 2 / 4 / 6 / 8 / 10 / 12 / 16 / 20 / 24 / 32

A 4px grid with three half-steps at 2, 6, and 10.

The half-steps are not a compromise. 6 and 10 are values the design independently
converged on in three separate files, and forcing them onto the grid would be a
visual redesign smuggled in as a refactor.

What kills drift is not the grid — it is that **the set is closed**. The guard
test asserts both that every `$space-*` value is a member and that there are
exactly ten of them, so adding an eleventh is a deliberate act with a failing
test attached, not a quiet edit.

> **Rule:** half-steps are legal for padding *inside* a control. Margins, gaps,
> and grid spacing use full steps.

### Type — 11 / 12 / 13 / 14 / 16 / 20

Integer-only steps at roughly a 1.09–1.25 ratio, tightening at the small end as
dense chrome should. Fractional sizes are avoided because GTK renders them
inconsistently.

Values that genuinely sit off the scale are named as one-offs so they cannot be
mistaken for steps: `$text-mono` (12.5), `$text-wlogout` (12.5), `$text-avatar`
(26), `$text-clock` (104). Adding a one-off is a design decision. It is *not* the
reflex fix for a failing assertion — that is usually the scale telling you the
value drifted.

Two places where the implementation deliberately rounds the mockup onto the
scale, and should stay rounded:

- The lock screen date is `$text-lg` (16); the design says 17.
- The lock screen avatar border is `$space-hair` (2); the design says 1.5.

**Font weights are whole hundreds, always.** GTK discards an *entire* stylesheet
when it meets a non-hundred weight. This is not theoretical: `swaync/style.css`
shipped `font-weight: 650` in two rules, which meant every other rule in that
file — all 346 lines of it — was silently doing nothing.

### Icons — 15 / 18 / 24 / 32, plus 40 hit and 56 ring

Icon glyph sizes are not type. A 16px icon and 16px text are different optical
systems, and coupling them means fixing one breaks the other. `$icon-hit` (40) is
a touch target; `$icon-ring` (56) is the wlogout button ring.

### Elevation — four tiers

Surface alpha, hairline opacity, and shadow move **together**. Tiering alpha
alone is why nothing read as layered before: the border brightens as the surface
opacifies, and both signal proximity to the viewer.

| Tier | Alpha | Border | Shadow |
|---|---|---|---|
| 0 | 0.88 | 0.10 | — |
| 1 | 0.92 | 0.08 | `0 1px 2px` @ 0.35 |
| 2 | 0.96 | 0.14 | `0 4px 12px` @ 0.45 |
| 3 | 0.96 | 0.16 | `0 8px 24px` @ 0.55 |

Hyprland has one global `decoration.shadow` and no per-layer shadow rule, so this
ramp is an **intra-panel** system. Windows sit at tier 2 permanently.

#### The contrast budget

The tier-0 alpha is load-bearing for legibility, not taste.

Muted text is `#9a9ca5` on a `#0f1115` surface. The surface is translucent, so
the effective background depends on what is behind it — and the worst case is a
bright wallpaper, which lightens the composite and *reduces* contrast against
already-light muted text.

At **0.82** alpha over white, muted text lands at **4.05:1** — under the WCAG AA
floor of 4.5:1 for body text. At **0.88** it clears it. That 0.06 is the entire
reason tier 0 is not glassier, and it is why `$elev-0-alpha` is a token rather
than a per-file literal: the AGS stylesheet used 0.82 and was below the floor on
any light wallpaper.

If you raise the glassiness, re-check this number first.

### Motion

Hyprland's animation unit is **deciseconds**, so durations that cross into
`motion/*.conf` are multiples of 100 and mirrored as `$ds-*`. `$dur-2` (150ms) is
CSS/QML-only for that reason.

The easing curves are stored as bare control points because Hyprland's `bezier =`
line wants them that way; CSS gets them wrapped in `cubic-bezier()` and QML as a
list for `easing.bezierCurve`, both derived by the renderer. Before this, the GTK
stylesheets used a plain `ease` and visibly disagreed with the compositor.

---

## Adding or changing a token

1. Edit `config/hypr/tokens.conf`. Keep the line shape `$name = value` — both the
   renderer's regex and the guard test assume it.
2. Reference it as `@name@` / `@name-px@` in the relevant `.in` template.
3. Run `theme.sh render`.
4. Run `tests/p7-token-smoke.sh`.
5. Commit the template *and* its rendered output together.

Before widening a scale, check whether the value wants to be a **named one-off**
instead. The scales are small on purpose; a scale with fourteen spacing steps is
a list of literals wearing a costume.
