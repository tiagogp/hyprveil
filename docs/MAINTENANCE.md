# Maintenance commands

Hyprveil ships a read-only doctor command for support reports and post-upgrade
triage:

```bash
./hyprveil doctor
```

The report covers:

- Fedora support status and the count of enabled official and third-party DNF
  repositories.
- Required and optional dependency presence, scoped to the selected notification
  backend.
- Hyprland config presence and `Hyprland --verify-config` when the command is
  installed.
- Quickshell deployment and live process health when run from inside Hyprland.
- Notification backend, hardware profile, motion profile, dock pins, wallpapers,
  and accent state.
- Hyprveil-managed config trees under `$XDG_CONFIG_HOME`, including retired or
  inactive notification backend trees left by older deployments.

`doctor` does not repair, rewrite, or delete anything. It prints recovery commands
next to failures and redacts paths under `$HOME` as `~` so reports can be pasted
without exposing the account's full home path. Wallpaper, dock, and accent JSON
state are schema-checked when `jq` is installed; without `jq`, the command warns
instead of modifying state.

Use it before and after a manual rollback:

```bash
./hyprveil doctor
ls -1dt "${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/backups"/*
./hyprveil doctor
```

The deeper validation gate remains:

```bash
./tests/run.sh
./scripts/03-test-config.sh
```
