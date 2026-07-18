# Fedora support policy

Hyprveil supports a rolling pair: the current stable Fedora release and the
immediately previous stable release. As of July 2026, that pair is Fedora 44 and
Fedora 43. `support/fedora-releases.conf` is the machine-readable source used by
the installer and validator.

When Fedora publishes a stable release, Hyprveil will:

1. add the new release and remove the older of the previous pair;
2. rerun the fresh-install, rerun, COPR-refusal, and profile matrix;
3. record the exercised versions in this file before creating a tag; and
4. describe any unavailable optional feature in the release notes.

Hyprveil may probe repositories on other Fedora versions, but prints a warning and
does not claim those versions are supported. Non-Fedora distributions are outside
the package installer's scope.

## Tagged-release test record

There are no Hyprveil tags yet. Every future tag must replace this placeholder with
a row recording the exact Fedora versions and result links or notes.

| Hyprveil tag | Fedora current | Fedora previous | Result |
|---|---:|---:|---|
| Unreleased P0 | 44 | 43 | Automated mocked checks pass; clean VM runs pending |

Detailed manual rows and required evidence are maintained in
[VM-TEST-MATRIX.md](VM-TEST-MATRIX.md). A release cannot replace the pending result
above until every row for both Fedora versions passes.

Official lifecycle and package information:

- [Fedora Linux releases](https://docs.fedoraproject.org/en-US/releases/)
- [Fedora package search](https://packages.fedoraproject.org/)
- [Fedora 44 download and release date](https://fedoraproject.org/workstation/download/)
