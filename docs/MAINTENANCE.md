# Maintenance commands

The `hyprveil` command groups the lifecycle operations that act on an existing
install: a re-openable first-run setup, a read-only health report, an in-place
update, a guided rollback, and an uninstall. All of them back up before they
change anything and keep persistent state (`$XDG_STATE_HOME/hyprveil`) separate
from the managed config trees.

```bash
./hyprveil setup         # first-run setup: monitors, keyboard, apps, idle, etc.
./hyprveil doctor        # read-only health report
./hyprveil update        # re-sync managed config from this checkout
./hyprveil rollback      # restore a timestamped backup
./hyprveil uninstall     # remove managed config, keep state and backups
```

## setup

```bash
./hyprveil setup                     # interactive first-run flow
./hyprveil setup --preview           # show the generated config and exit
./hyprveil setup --yes               # unattended: accept detected defaults
```

`setup` is the first-run experience, and it is safe to re-run at any time —
nothing gates on a completion marker, and cancelling at the confirmation prompt
leaves the existing configuration and state untouched. It:

- detects connected monitors (`hyprctl monitors`) and offers their preferred
  resolution, position, and scale;
- collects keyboard layout/variant, the terminal/browser/file-manager/editor
  used by the keybindings, idle-lock/DPMS/suspend timers, and (by delegation)
  the wallpaper, accent mode, motion profile, hardware profile, notification
  backend, and optional SDDM greeter;
- previews the exact files it will write, then deploys and reloads the session.

Every choice has a flag, so the whole flow can run unattended or be scripted.
Run `./scripts/10-first-run-setup.sh --help` for the complete list. Common ones:

```bash
./hyprveil setup \
    --monitor 'DP-1:2560x1440@144:0x0:1:primary' \
    --monitor 'HDMI-A-1:1920x1080@60:2560x0:1' \
    --kb-layout us --kb-variant intl \
    --terminal kitty --browser firefox --file-manager nautilus --editor code \
    --idle-lock 600 --idle-dpms 900 --idle-suspend 1800 \
    --accent auto --motion standard --yes
```

The `--monitor` spec is `NAME:MODE:POSITION:SCALE[:TRANSFORM][:primary]`; repeat
it once per display. `TRANSFORM` is a Hyprland transform (0–7); any idle timer
set to `0` disables that listener.

Setup writes three generated files into `~/.config/hypr` — `local.conf`
(monitors + keyboard, sourced last so it wins), `apps.conf` (the app shortcut
variables), and `hypridle.conf` (idle timers) — from canonical choices saved
under `$XDG_STATE_HOME/hyprveil` (`setup.conf`, `monitors.tsv`, both `0600`). A
deploy resets those files to their repository defaults, so `hyprveil update`
re-runs `setup --ensure` afterwards to regenerate them from the saved state; your
setup choices survive updates the same way the hardware and backend profiles do.

## doctor

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

Use it before and after an update or rollback:

```bash
./hyprveil doctor
./hyprveil update
./hyprveil doctor
```

## update

```bash
./hyprveil update            # preview, confirm, deploy, validate, reload
./hyprveil update --preview  # show pending changes and exit
./hyprveil update --yes      # skip the confirmation prompt
```

`update` re-deploys the managed config trees from this checkout. It first prints a
preview of the trees that differ from the repository, then — after confirmation —
backs up the existing configuration to a timestamped snapshot, deploys the new
trees atomically, restores the saved hardware/backend/motion/accent state, and
validates the result (`hyprland.conf` matches the template and, when available,
`Hyprland --verify-config` accepts it) *before* reloading the live session. If
validation fails it stops without reloading and points at `./hyprveil rollback`.

Persistent state under `$XDG_STATE_HOME/hyprveil` — pins, wallpaper mappings,
accent, motion, and backend selection — is preserved across the update. Generated
accent and token fragments are re-rendered from saved state, so a wallpaper-derived
accent survives.

## rollback

```bash
./hyprveil rollback --list                       # list snapshots, newest first
./hyprveil rollback                              # choose one interactively
./hyprveil rollback --backup 20260720-120000 --yes
```

`rollback` restores the managed config trees from a chosen backup snapshot without
manual path construction. It backs up the current configuration first, so the
rollback itself is reversible. See [RECOVERY.md](RECOVERY.md) for the manual
equivalent.

## uninstall

```bash
./hyprveil uninstall                             # remove managed config, keep state
./hyprveil uninstall --export-state ~/hyprveil-state-backup
./hyprveil uninstall --purge-state               # also delete state after a second prompt
./hyprveil uninstall --sddm                      # also restore the previous SDDM config (sudo)
```

`uninstall` backs up and removes only Hyprveil-owned user config trees (including
inactive and retired notification backends and `starship.toml`). It never removes
installed packages or enabled repositories. Persistent state and backups are
preserved by default; `--export-state` copies them elsewhere first and
`--purge-state` deletes them after an explicit second confirmation. With `--sddm`
it restores the previous SDDM theme and selection Hyprveil installed (or removes
Hyprveil's own files when there was nothing to restore); it never switches the
active display manager for you.

The deeper validation gate remains:

```bash
./tests/run.sh
./scripts/03-test-config.sh
```
