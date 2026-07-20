# Hyprveil improvement plan

This checklist tracks the work needed to turn Hyprveil from a strong personal
desktop configuration into a polished, publicly reusable Fedora template. The
existing `ROADMAP.md` remains the source for feature milestone history; this file
is the practical adoption, release, and product-polish backlog.

## 1. Fix project consistency

- [x] Rewrite `README.md` around the current product rather than its delivery history.
  - [x] Remove conversation-specific wording such as "per your preference" and
        "this delivery."
  - [x] Replace the completed stage narrative with a concise current feature list.
  - [x] Move implementation history and superseded architecture notes to
        `ROADMAP.md` or a changelog.
  - [x] Put requirements, supported Fedora releases, install command, and important
        warnings near the top.
- [x] Audit all documentation against the current Quickshell architecture.
  - [x] Describe Quickshell as the default shell and notification backend everywhere.
  - [x] Keep Waybar, SwayNC, and Mako clearly labeled as legacy or fallback components.
  - [x] Update managed-tree lists to include Quickshell and all currently deployed
        theme and shell configuration.
  - [x] Update test references from P0-P4 to P0-P8 where appropriate.
  - [x] Correct stale file paths, design-file names, commands, and directory trees.
- [x] Fix the live-session installer reload path.
  - [x] Restart Quickshell instead of unconditionally restarting Waybar.
  - [x] Restart only the selected notification backend.
  - [x] Make the completion message name the components actually reloaded.
  - [x] Add a smoke test for the selected reload path.
- [x] Run a repository-wide terminology audit for `AGS`, `Waybar`, backend names,
      milestone numbers, and retired commands.

### Acceptance

- [x] A new reader can understand what Hyprveil is, what it changes, and how to try
      it without reading the roadmap.
- [x] Every documented command and path exists in a clean checkout.
- [x] Documentation contains no accidental claims that retired components are the
      default implementation.

## 2. Show the actual desktop

- [ ] Add a screenshot gallery to the README.
  - [ ] Desktop overview with bar and dock.
  - [ ] Quick Settings with Wi-Fi, Bluetooth, and notifications.
  - [ ] Wallpaper picker and per-monitor controls.
  - [ ] Keybind cheatsheet.
  - [ ] Lock screen.
  - [ ] SDDM greeter.
- [ ] Record a short compressed demo showing the launcher, workspace motion, Quick
      Settings, wallpaper selection, notifications, and lock flow.
- [ ] Store media in a predictable `docs/assets/` tree with descriptive filenames.
- [ ] Document the Fedora version, display scale, and commit used for each release
      screenshot set.
- [ ] Check that README media renders well on desktop and mobile GitHub layouts.

### Acceptance

- [ ] The first README viewport contains the Hyprveil name, a real desktop image,
      a one-paragraph description, and a direct path to installation.
- [ ] Images show inspectable UI rather than only blurred or atmospheric wallpaper.

## 3. Add public-project foundations

- [x] Choose and add a `LICENSE`.
- [x] Add `CONTRIBUTING.md` covering local validation, QML conventions, generated
      theme files, documentation updates, and manual hardware testing.
- [x] Add `CHANGELOG.md` using a consistent release format.
- [x] Add `SECURITY.md` with a private reporting path for installer, lock-screen,
      authentication, and privilege-boundary issues.
- [x] Add GitHub issue templates for bug reports, hardware compatibility reports,
      and feature requests.
- [x] Add a pull request template with automated and manual validation checkboxes.
- [x] Add an `.editorconfig` for shell, QML, CSS, JSON, and Markdown files.

## 4. Add continuous integration

- [x] Add a GitHub Actions workflow for pull requests and the default branch.
- [x] Install ShellCheck and all non-session test dependencies in CI.
- [x] Run `./tests/run.sh --require-shellcheck` from a clean checkout.
- [x] Verify generated token and accent outputs remain synchronized with templates.
- [x] Add Markdown link and formatting checks without requiring network access for
      ordinary local tests.
- [x] Add a release workflow that validates the tag commit before publishing notes.
- [ ] Add status badges only after the corresponding checks are stable.

### Acceptance

- [x] CI catches shell syntax, ShellCheck, JSON/JSONC, executable-bit, generated-file,
      and P0-P8 smoke-test regressions.
- [x] The commands run in CI are the same commands documented for contributors.

## 5. Complete hardware validation and publish the first release

- [ ] Complete every Fedora 44 row in `docs/VM-TEST-MATRIX.md`.
- [ ] Complete every Fedora 43 row in `docs/VM-TEST-MATRIX.md`.
- [ ] Record clean install, rerun, upgrade, COPR refusal, fallback, nested-session,
      and rollback evidence for both releases.
- [ ] Test the Quickshell Wi-Fi section with real NetworkManager hardware.
- [ ] Test Bluetooth power, discovery, connection, battery reporting, and alerts on
      real hardware.
- [ ] Test desktop and laptop profiles on representative Intel, AMD, and NVIDIA
      systems where available.
- [ ] Test single-monitor, mixed-scale multi-monitor, and monitor disconnect/reconnect
      behavior.
- [ ] Run the complete `docs/RELEASE.md` checklist against one exact commit.
- [ ] Update support records so no release result remains `Pending`.
- [ ] Create release notes, tag the validated commit, and publish the first versioned
      Hyprveil release.

## 6. Build a first-run setup experience

- [ ] Create a first-run command or Quickshell flow that can be safely reopened later.
- [ ] Detect connected monitors and offer preferred-resolution defaults.
- [ ] Support monitor position, scale, refresh rate, transform, and primary-display
      selection.
- [ ] Offer keyboard layout and locale selection without assuming US defaults.
- [ ] Confirm or change the detected desktop/laptop and GPU profile.
- [ ] Let the user choose terminal, browser, file manager, and editor shortcuts from
      installed desktop entries.
- [ ] Let the user choose Quickshell, SwayNC, or Mako notification behavior where the
      fallback choice is useful.
- [ ] Offer wallpaper, accent mode, motion profile, idle timers, and optional SDDM
      setup.
- [ ] Preview the generated configuration before deployment.
- [ ] Save completion state under `$XDG_STATE_HOME/hyprveil` without preventing the
      setup flow from being run again.

### Acceptance

- [ ] A fresh install reaches a usable desktop without requiring manual edits to
      `monitors.conf` for common single-monitor hardware.
- [ ] Cancelling setup leaves existing configuration and persistent state intact.
- [ ] Every first-run choice has a documented command-line alternative.

## 7. Add maintenance commands

- [x] Add a `hyprveil doctor` command.
  - [x] Report Fedora support status and enabled package sources.
  - [x] Report required and optional dependency status.
  - [x] Check Hyprland configuration errors and Quickshell startup health.
  - [x] Report notification backend, wallpaper, accent, motion, dock, and hardware
        profile state.
  - [x] Detect stale managed trees and malformed state without modifying them.
  - [x] Print actionable recovery commands and redact private data from reports.
- [ ] Add a documented update command that previews changes, backs up managed trees,
      preserves state, deploys atomically, and validates before reload.
- [ ] Add a rollback command that lists backups and restores a selected snapshot
      without manual path construction.
- [ ] Add an uninstall command.
  - [ ] Remove only Hyprveil-owned user configuration after confirmation.
  - [ ] Preserve or optionally export user state and backups.
  - [ ] Restore the previous SDDM configuration when Hyprveil installed it.
  - [ ] Do not remove shared packages or repositories unless explicitly requested.
- [ ] Add mocked tests for update, rollback, cancellation, and uninstall paths.

## 8. Add desktop interaction polish

- [ ] Add matching on-screen displays for volume, mute, microphone mute, and brightness.
- [ ] Coalesce repeated key presses so OSDs update smoothly instead of stacking.
- [ ] Add audio output, audio input, and per-stream controls to Quick Settings.
- [ ] Add laptop power-profile controls for performance, balanced, and power saver
      when the system exposes them.
- [ ] Add a searchable clipboard history panel with clear-item and clear-all actions.
- [ ] Add Bluetooth pairing support with a BlueZ `Agent1` implementation or a clearly
      integrated Blueman agent fallback.
- [ ] Add optional Kitty tab/session helpers without making Kitty state part of the
      core shell process.
- [ ] Consider narrowly scoped per-app GTK/Qt fixes only for confirmed visual defects.

### Acceptance

- [ ] Every optional control hides or degrades cleanly when its service or hardware
      is unavailable.
- [ ] New controls use the existing token, accent, surface, and icon systems.
- [ ] New persistent state is schema-checked, private where appropriate, atomic, and
      preserved across deployment.

## 9. Accessibility and interaction quality

- [ ] Verify complete keyboard navigation in Quick Settings, wallpaper picker,
      cheatsheet, dock picker, lock screen, and SDDM session picker.
- [ ] Add visible focus states that meet the design contrast budget.
- [ ] Verify screen-reader labels or accessible names for icon-only controls where
      supported by the QML stack.
- [ ] Test text clipping with long network names, Bluetooth names, media metadata,
      usernames, translated dates, and application names.
- [ ] Test at 1x, 1.25x, 1.5x, and 2x scale, including mixed-scale monitors.
- [ ] Confirm reduced-motion mode covers every newly added animated surface.
- [ ] Confirm notification, lock, and power actions remain usable without a pointer.

## Definition of done for every item

- [ ] Implementation follows the repository's existing ownership and state patterns.
- [ ] Automated coverage is proportional to the behavior and failure risk.
- [ ] Relevant documentation and recovery instructions are updated in the same change.
- [ ] Manual-only behavior records the Fedora version, hardware, commit, and result.
- [ ] `./tests/run.sh --require-shellcheck` passes before release.
- [ ] No unrelated user configuration or persistent state is overwritten.
