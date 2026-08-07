#!/usr/bin/env bash
# Re-apply the selected accent provider to the currently saved wallpaper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
provider=${1:-hyprveil}
path=$($SCRIPT_DIR/wallpaper.sh list | jq -r '.fallback.path // empty')
[ -n "$path" ] || exit 0
case "$provider" in
    hyprveil) exec "$SCRIPT_DIR/accent.sh" from-wallpaper "$path" ;;
    matugen) exec "$SCRIPT_DIR/matugen-adapter.sh" from-wallpaper "$path" ;;
    *) printf 'Unknown accent provider: %s\n' "$provider" >&2; exit 2 ;;
esac
