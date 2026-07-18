# Manual Fedora VM test matrix

Automated smoke tests are necessary but do not replace clean Fedora installs. Run
this matrix for both releases listed in `support/fedora-releases.conf` before a tag.
Use snapshots so every “fresh” row starts without prior Hyprveil config or state.

Record the date, Fedora image/build, Hyprveil commit, GPU/display setup, tester, and
evidence link or concise notes. `Pending` is not a passing release result.

## Fedora 44

| Scenario | Required observations | Result | Evidence/notes |
|---|---|---|---|
| Fresh install | official-first probes, selected backend, login, bar, wallpaper | Pending | — |
| Rerun | no duplicate COPR; timestamped backup; state unchanged | Pending | — |
| Upgrade | old pins/wallpapers/motion/backend restored after replacement | Pending | — |
| COPR refusal | no repo mutation; required failure blocks copy; SwayNC refusal selects Mako | Pending | — |
| Fallbacks | Mako, no Bluetooth adapter, no battery/backlight, missing optional tools | Pending | — |
| Nested session | isolated shell launches and exits without changing host config/state | Pending | — |

## Fedora 43

| Scenario | Required observations | Result | Evidence/notes |
|---|---|---|---|
| Fresh install | official-first probes, selected backend, login, bar, wallpaper | Pending | — |
| Rerun | no duplicate COPR; timestamped backup; state unchanged | Pending | — |
| Upgrade | old pins/wallpapers/motion/backend restored after replacement | Pending | — |
| COPR refusal | no repo mutation; required failure blocks copy; SwayNC refusal selects Mako | Pending | — |
| Fallbacks | Mako, no Bluetooth adapter, no battery/backlight, missing optional tools | Pending | — |
| Nested session | isolated shell launches and exits without changing host config/state | Pending | — |

## Procedure

1. Save baseline copies or checksums of `~/.config` and
   `$XDG_STATE_HOME/hyprveil`; create representative pins, per-monitor wallpaper,
   reduced motion, and a notification backend choice before rerun/upgrade rows.
2. Run `./tests/run.sh --require-shellcheck` and
   `./scripts/03-test-config.sh` outside Hyprland.
3. Run `./install.sh`, recording repository prompts and preflight.
4. Log into Hyprland and exercise Bluetooth, media, notifications, dock actions,
   wallpaper restore, standard/reduced motion, lock, idle, and power UI.
5. Rerun or upgrade, then compare state values and verify a timestamped config
   backup exists. Follow [RECOVERY.md](RECOVERY.md) once to prove rollback.
6. Replace `Pending` with `Pass` or `Fail`, add evidence, and summarize the two
   release results in [SUPPORT.md](SUPPORT.md).
