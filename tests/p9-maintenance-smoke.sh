#!/usr/bin/env bash
# Mocked, non-root checks for the maintenance commands: update preview and
# deploy, rollback listing and restore, cancellation safety, and uninstall
# (config removal, state preservation, export, and purge).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p9.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

cat > "$TMP/os-release" <<'EOF'
ID=fedora
VERSION_ID=44
PRETTY_NAME="Fedora Linux 44 (Mock)"
EOF

export HOME="$TMP/home"
export HYPRVEIL_OS_RELEASE="$TMP/os-release"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_NO_SUDO=1
export PATH="$TMP/bin:$PATH"
mkdir -p "$HOME" "$HYPRVEIL_CONFIG_HOME" "$HYPRVEIL_STATE_HOME" "$TMP/bin"

# Hyprland stub accepts --verify-config so update's validation step passes.
cat > "$TMP/bin/Hyprland" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = --verify-config ] && exit 0
exit 0
EOF
chmod +x "$TMP/bin/Hyprland"

# A minimal notification backend and profile so deploy and doctor stay quiet.
printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
cat > "$HYPRVEIL_STATE_HOME/hardware-profile.conf" <<'EOF'
form_factor=desktop
gpu=intel
EOF

# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
hv_load_fedora

# Establish a clean deployment from the repository.
hv_deploy_configs >/dev/null
[ -f "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf" ] || fail "initial deploy did not install hyprland.conf"
ok "initial deployment established from repository"

# --- update: no-op when already synchronized --------------------------------
update_out=$("$REPO/hyprveil" update --preview)
printf '%s' "$update_out" | grep -q 'already matches the repository' \
    || fail "update --preview did not report an up-to-date deployment"
ok "update --preview reports no pending changes on a fresh deployment"

# --- update: preview detects drift without changing anything -----------------
printf 'local drift\n' >> "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf"
drift_before=$(sha256sum "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf")
preview_out=$("$REPO/hyprveil" update --preview)
printf '%s' "$preview_out" | grep -q 'changed   hypr' \
    || fail "update --preview did not report the drifted hypr tree"
printf '%s' "$preview_out" | grep -q 'Preview only; no changes were made' \
    || fail "update --preview applied changes"
drift_after=$(sha256sum "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf")
[ "$drift_before" = "$drift_after" ] || fail "update --preview modified the deployed config"
ok "update --preview detects drift without modifying the deployment"

# --- update: cancellation leaves the deployment untouched --------------------
cancel_before=$(sha256sum "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf")
printf 'n\n' | "$REPO/hyprveil" update >/dev/null
cancel_after=$(sha256sum "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf")
[ "$cancel_before" = "$cancel_after" ] || fail "cancelled update still changed the deployment"
ok "declining update leaves the drifted deployment unchanged"

# --- update: apply re-syncs the managed tree and records a backup ------------
backups_before=$(find "$HYPRVEIL_STATE_HOME/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
"$REPO/hyprveil" update --yes >/dev/null
cmp -s "$REPO/config/hypr/hyprland.conf" "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf" \
    || fail "update did not restore hyprland.conf to the managed template"
backups_after=$(find "$HYPRVEIL_STATE_HOME/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
[ "$backups_after" -gt "$backups_before" ] || fail "update did not create a backup snapshot"
find "$HYPRVEIL_STATE_HOME/backups" -path '*/config/hypr/hyprland.conf' -print -quit | grep -q . \
    || fail "update backup did not capture the previous hypr tree"
ok "update deploys atomically, re-syncs drift, and backs up the prior config"

# --- rollback: list and restore a selected snapshot --------------------------
list_out=$("$REPO/hyprveil" rollback --list)
printf '%s' "$list_out" | grep -q 'Available backups' || fail "rollback --list produced no listing"
# The snapshot captured the drifted config; restoring it must bring drift back.
snapshot=$(find "$HYPRVEIL_STATE_HOME/backups" -path '*/config/hypr/hyprland.conf' -printf '%h\n' \
    | sed 's#/config/hypr$##' | sort -r | head -1)
snapshot_name=$(basename "$snapshot")
"$REPO/hyprveil" rollback --backup "$snapshot_name" --yes >/dev/null
grep -q 'local drift' "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf" \
    || fail "rollback did not restore the drifted config from the snapshot"
find "$HYPRVEIL_STATE_HOME/backups" -newer "$snapshot/config" -path '*/config/hypr*' -print -quit >/dev/null 2>&1
ok "rollback lists snapshots and restores the selected one, backing up current first"

# --- rollback: cancellation leaves the deployment untouched ------------------
rb_before=$(sha256sum "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf")
printf '\n' | "$REPO/hyprveil" rollback >/dev/null
rb_after=$(sha256sum "$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf")
[ "$rb_before" = "$rb_after" ] || fail "cancelled rollback changed the deployment"
ok "cancelling rollback at the prompt leaves the deployment unchanged"

# Re-sync so uninstall starts from a clean managed deployment.
"$REPO/hyprveil" update --yes >/dev/null

# --- uninstall: cancellation preserves everything ----------------------------
printf 'n\n' | "$REPO/hyprveil" uninstall >/dev/null
[ -d "$HYPRVEIL_CONFIG_HOME/hypr" ] || fail "cancelled uninstall removed managed config"
ok "declining uninstall preserves the managed config"

# --- uninstall: exports state, removes config, preserves state by default ----
printf 'sentinel\n' > "$HYPRVEIL_STATE_HOME/notification-backend.marker"
"$REPO/hyprveil" uninstall --yes --export-state "$TMP/export" >/dev/null
[ ! -e "$HYPRVEIL_CONFIG_HOME/hypr" ] || fail "uninstall did not remove the hypr config tree"
[ ! -e "$HYPRVEIL_CONFIG_HOME/quickshell" ] || fail "uninstall did not remove the quickshell config tree"
[ ! -e "$HYPRVEIL_CONFIG_HOME/starship.toml" ] || fail "uninstall did not remove starship.toml"
[ -f "$HYPRVEIL_STATE_HOME/notification-backend" ] || fail "uninstall removed preserved state"
[ -f "$TMP/export/notification-backend.marker" ] || fail "uninstall did not export state"
find "$HYPRVEIL_STATE_HOME/backups" -path '*/config/hypr/hyprland.conf' -print -quit | grep -q . \
    || fail "uninstall did not back up removed config"
ok "uninstall exports state, removes managed config, and preserves state and backups"

# --- uninstall --purge-state removes state after a second confirmation -------
# Re-deploy so there is something to remove, then purge.
hv_deploy_configs >/dev/null
"$REPO/hyprveil" uninstall --yes --purge-state >/dev/null
[ ! -e "$HYPRVEIL_STATE_HOME" ] || fail "uninstall --purge-state left state behind"
ok "uninstall --purge-state removes state and backups on confirmation"

printf 'P9 maintenance smoke tests passed.\n'
