# Contributing

Thanks for helping make Hyprveil a reusable Fedora desktop template. The safest
changes are small, documented, and validated from a clean checkout.

## Local Validation

Run the non-session gate before opening a pull request:

```bash
./tests/run.sh
```

Release-bound changes must pass the stricter gate:

```bash
./tests/run.sh --require-shellcheck
```

When a change affects live Hyprland behavior, also run:

```bash
./scripts/03-test-config.sh
```

The nested-session phase must be launched manually from a Wayland session. It
redirects `HOME` and writable XDG paths into a temporary stage.

## QML Conventions

- Keep Quickshell as the default shell implementation.
- Use the shared `Tokens`, `Accent`, `Surface`, and `Glyph` helpers before adding
  one-off dimensions, colors, blur surfaces, or icon text.
- Keep optional hardware and service controls hidden or visibly unavailable when
  the service is not present.
- Avoid hardcoded keybinding descriptions in QML; the cheatsheet is rendered from
  `config/hypr/keybindings.conf`.

## Generated Theme Files

Generated outputs are committed so a clean checkout looks like an installed
configuration. Do not edit generated outputs directly.

- Edit design tokens in `config/hypr/tokens.conf` and token-only templates such
  as `config/quickshell/Tokens.qml.in`, then run:

```bash
config/hypr/scripts/theme.sh render
```

- Edit accent-bearing templates such as `config/quickshell/Accent.qml.in`,
  `config/mako/config.in`, Qt palette templates, or wlogout SVG sources, then
  run:

```bash
config/hypr/scripts/accent.sh render
```

`tests/p6-accent-smoke.sh` and `tests/p7-token-smoke.sh` fail when committed
outputs drift from their templates.

## Documentation

Update documentation in the same change when behavior, paths, commands, state
schemas, dependencies, keybindings, or recovery steps change. Keep Waybar, SwayNC,
and Mako described as legacy or fallback components unless their role changes.

## Manual Hardware Testing

Manual-only behavior should record:

- Fedora release and image/build.
- Hardware model, GPU path, Bluetooth/Wi-Fi chipset when relevant.
- Display scale and monitor layout.
- Hyprveil commit.
- Result and recovery notes.

Use `docs/VM-TEST-MATRIX.md` and `docs/SUPPORT.md` for release evidence.
