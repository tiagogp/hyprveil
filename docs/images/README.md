# Screenshots

This directory holds the images the main [README](../../README.md) embeds:
`desktop.png`, `desktop-accent.png`, `launcher.png`, `wallpaper-picker.png`,
`cheatsheet.png`, plus the connected-flow `shell-demo.webm`.

After changing bar geometry, capture `desktop.png` at 1920×1080 and also check
the live layout at 1280 logical pixels before replacing it. The three islands,
their transparent gaps, and the bottom dock must all be visible; do not use a
generated mockup as the project screenshot. `tests/capture-shell.sh` drives the
public CLI to refresh the stills and the demo from a live Hyprland session.
