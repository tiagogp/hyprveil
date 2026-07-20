# Security Policy

Hyprveil changes user session configuration and can optionally install an SDDM
theme, so installer safety, lock behavior, authentication surfaces, and privilege
boundaries should be reported carefully.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub private
vulnerability reporting for this repository when it is available. If private
reporting is unavailable, contact the repository owner through the maintainer
profile and avoid opening a public issue with exploit details.

Include the affected commit, Fedora release, reproduction steps, expected impact,
and whether the issue touches installer privileges, SDDM, lock-screen behavior,
or user configuration backups.

## Scope

Security-sensitive areas include:

- `install.sh` and installer stages that install packages or copy configuration.
- Backup, rollback, and managed-tree replacement behavior.
- `config/quickshell/Lock/` and `config/hypr/hyprlock.conf`.
- `config/sddm/hyprveil/` and `scripts/05-install-fedora-sddm.sh`.
- Scripts that cross process, user, repository, or service boundaries.

Please do not publish working exploit details until maintainers have had a
reasonable chance to respond.
