# Release checklist

A Hyprveil tag is a reusable-template claim. Do not mark a roadmap milestone or a
release complete from mocked checks alone.

## Automated gate

- [ ] `./tests/run.sh --require-shellcheck` passes from a clean checkout.
- [ ] CI passes ShellCheck, Bash syntax, JSON/JSONC parsing, executable checks,
      offline Markdown checks, generated-file checks, and all P0-P10 non-session
      smoke tests.
- [ ] `./scripts/03-test-config.sh` passes static validation on supported Fedora.
- [ ] A nested session launches from each selected notification backend without
      modifying real config or state.
- [ ] `Hyprland --verify-config` passes on both supported Fedora package versions,
      or the nested launch records the parse result when the option is unavailable.

## Milestone and VM gate

- [ ] Every P0, P1, P2, and P3 deliverable and acceptance item in `ROADMAP.md` is
      checked and backed by tests, documentation, or recorded manual evidence.
- [ ] Every P4 deliverable is present; no P4 acceptance item remains unchecked.
- [ ] All Fedora 44 rows in [VM-TEST-MATRIX.md](VM-TEST-MATRIX.md) pass.
- [ ] All Fedora 43 rows in [VM-TEST-MATRIX.md](VM-TEST-MATRIX.md) pass.
- [ ] Fresh install, rerun, and upgrade preserve dock pins, wallpaper mappings,
      motion selection, notification backend, and hardware profile.
- [ ] COPR refusal and Mako fallback paths are exercised without unintended repo
      changes.
- [ ] Recovery is exercised for Hyprland, Quickshell, Hyprpaper, the selected
      notification backend, and the legacy Waybar fallback.

## Documentation and tag gate

- [ ] `support/fedora-releases.conf` names the current and previous stable Fedora.
- [ ] `docs/SUPPORT.md` records exact VM images, dates, results, and evidence.
- [ ] Configuration, optional dependencies, hardware, keybindings, state, upgrades,
      rollback, and recovery documentation matches the shipped interfaces.
- [ ] Release notes identify unavailable optional features and repository sources.
- [ ] Version/tag references and the README are updated; no result says `Pending`.
- [ ] The release commit is the commit tested in the VM matrix.

Only after every checkbox above is satisfied should P0 and P4 be marked `Complete`
and the tag be created.
