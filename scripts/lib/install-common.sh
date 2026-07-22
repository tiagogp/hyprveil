#!/usr/bin/env bash
# Shared Fedora detection, repository selection, state, and config deployment.
# This file is sourced by the installer stages; it is not meant to be run directly.

HV_REPO="${HV_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HV_STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
HV_CONFIG_HOME="${HYPRVEIL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
HV_SOURCE_LOG="$HV_STATE_HOME/package-sources.tsv"
HV_NOTIFICATION_STATE="$HV_STATE_HOME/notification-backend"

if [ -r "$HV_REPO/scripts/lib/cli-ui.sh" ]; then
    # shellcheck disable=SC1091
    . "$HV_REPO/scripts/lib/cli-ui.sh"
fi

hv_color_enabled() {
    if declare -F ui_supports_color >/dev/null 2>&1; then
        ui_supports_color
    else
        [ -z "${NO_COLOR:-}" ] || return 1
        case "${HYPRVEIL_COLOR:-auto}" in
            always) return 0 ;;
            never) return 1 ;;
        esac
        [ -t 1 ] && [ "${TERM:-}" != dumb ]
    fi
}

hv_style() {
    local code=$1 text=$2
    if declare -F ui_style >/dev/null 2>&1; then
        ui_style "$code" "$text"
    elif hv_color_enabled; then
        printf '\033[%sm%s\033[0m' "$code" "$text"
    else
        printf '%s' "$text"
    fi
}

hv_banner() {
    local detail=${1:-}
    if declare -F print_header >/dev/null 2>&1; then
        print_header "Hyprveil" "$detail"
        return
    fi
    printf '\n%s\n' "$(hv_style '1;36' "Hyprveil")"
    [ -z "$detail" ] || printf '  %s\n' "$(hv_style '2' "$detail")"
    printf '\n'
}

hv_section() {
    local title=$1 detail=${2:-}
    if declare -F print_section >/dev/null 2>&1; then
        print_section "$title" "$detail"
        return
    fi
    printf '\n%s %s\n' "$(hv_style '2' "::")" "$(hv_style '1;36' "$title")"
    [ -z "$detail" ] || printf '   %s\n' "$(hv_style '2' "$detail")"
}

hv_step() {
    local number=$1 title=$2
    printf -v number '%02d' "$number"
    printf '\n%s %s\n' "$(hv_style '1;36' "[$number]")" "$(hv_style '1' "$title")"
}

hv_note() {
    if declare -F print_info >/dev/null 2>&1; then print_info "$*"; else printf '  %s %s\n' "$(hv_style '1;34' INFO)" "$*"; fi
}
hv_ok() {
    if declare -F print_success >/dev/null 2>&1; then print_success "$*"; else printf '  %s   %s\n' "$(hv_style '1;32' OK)" "$*"; fi
}
hv_warn() {
    if declare -F print_warning >/dev/null 2>&1; then print_warning "$*"; else printf '  %s %s\n' "$(hv_style '1;33' WARN)" "$*" >&2; fi
}
hv_bad() {
    if declare -F print_error >/dev/null 2>&1; then print_error "$*"; else printf '  %s %s\n' "$(hv_style '1;31' FAIL)" "$*" >&2; fi
}

hv_confirm() {
    local prompt=$1 answer
    if declare -F confirm_action >/dev/null 2>&1; then
        confirm_action "$prompt" no
        return $?
    fi
    if [ "${HYPRVEIL_ASSUME_YES:-0}" = 1 ]; then
        printf '%s %s [automatic yes]\n' "$(hv_style '1;34' AUTO)" "$prompt"
        return 0
    fi
    read -r -p "$(hv_style '1;34' ASK) $prompt [y/N] " answer
    [[ "$answer" = y || "$answer" = Y ]]
}

# Like hv_confirm, but strictly defaults to "no" even under gum (which otherwise
# highlights "Yes"). For system-altering steps where an accidental Enter must
# never proceed.
hv_confirm_no() {
    local prompt=$1 answer
    if declare -F confirm_action >/dev/null 2>&1; then
        confirm_action "$prompt" no strict
        return $?
    fi
    if [ "${HYPRVEIL_ASSUME_YES:-0}" = 1 ]; then
        printf '%s %s [automatic yes]\n' "$(hv_style '1;34' AUTO)" "$prompt"
        return 0
    fi
    read -r -p "$(hv_style '1;34' ASK) $prompt [y/N] " answer
    [[ "$answer" = y || "$answer" = Y ]]
}

hv_load_fedora() {
    local os_release=${HYPRVEIL_OS_RELEASE:-/etc/os-release}
    if [ ! -r "$os_release" ]; then
        hv_bad "cannot read $os_release"
        return 1
    fi

    local ID='' VERSION_ID='' PRETTY_NAME=''
    # os-release is a shell-compatible, distribution-owned data file.
    # shellcheck disable=SC1090
    . "$os_release"
    HV_OS_ID=${ID:-unknown}
    HV_FEDORA_VERSION=${VERSION_ID:-unknown}
    HV_OS_NAME=${PRETTY_NAME:-$HV_OS_ID $HV_FEDORA_VERSION}
    if [ "$HV_OS_ID" != fedora ]; then
        hv_bad "Hyprveil's package installer supports Fedora; detected $HV_OS_NAME"
        return 1
    fi
}

hv_supported_releases() {
    # shellcheck disable=SC1091
    . "$HV_REPO/support/fedora-releases.conf"
    printf '%s\n' "$HYPRVEIL_SUPPORTED_FEDORA"
}

hv_check_supported_release() {
    local supported release
    supported=$(hv_supported_releases)
    for release in $supported; do
        if [ "$HV_FEDORA_VERSION" = "$release" ]; then
            hv_ok "Fedora $HV_FEDORA_VERSION is in the supported release pair ($supported)"
            return 0
        fi
    done
    hv_warn "Fedora $HV_FEDORA_VERSION is outside the supported release pair ($supported)"
    hv_warn "repository probing will still run, but this combination is not release-tested"
    return 1
}

hv_dnf() {
    "${HYPRVEIL_DNF:-dnf}" "$@"
}

hv_is_official_repo() {
    case "$1" in
        fedora|fedora-debuginfo|fedora-source|updates|updates-debuginfo|updates-source|updates-testing|updates-testing-debuginfo|updates-testing-source)
            return 0
            ;;
        *) return 1 ;;
    esac
}

hv_enabled_repo_ids() {
    hv_dnf -q repolist --enabled 2>/dev/null \
        | awk '$1 == "repo" && $2 == "id" {next} $1 !~ /^(Updating|Repositories)/ {print $1}' \
        | sed '/^$/d'
}

hv_show_enabled_repos() {
    local repos
    if ! command -v "${HYPRVEIL_DNF:-dnf}" >/dev/null 2>&1; then
        hv_bad "dnf is unavailable; package sources cannot be probed"
        return 1
    fi
    repos=$(hv_enabled_repo_ids || true)
    if [ -n "$repos" ]; then
        printf 'Enabled repositories:\n'
        while IFS= read -r repo; do
            printf '  %s\n' "$repo"
        done <<<"$repos"
    else
        hv_warn "dnf returned no enabled repositories"
    fi
}

hv_package_repos() {
    local package=$1
    hv_dnf -q repoquery --available --qf '%{repoid}\n' "$package" 2>/dev/null \
        | sed '/^$/d' | sort -u
}

hv_official_package_source() {
    local package=$1 repo
    local -a args=(-q)
    while IFS= read -r repo; do
        hv_is_official_repo "$repo" && args+=("--repo=$repo")
    done < <(hv_enabled_repo_ids)
    [ "${#args[@]}" -gt 1 ] || return 1
    args+=(repoquery --available --latest-limit=1 --qf '%{repoid}\n' "$package")
    hv_dnf "${args[@]}" 2>/dev/null | sed '/^$/d' | sed -n '1p'
}

hv_package_source() {
    local package=$1 repo first=
    repo=$(hv_official_package_source "$package" || true)
    if [ -n "$repo" ] && hv_is_official_repo "$repo"; then
        printf '%s\n' "$repo"
        return 0
    fi
    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        [ -n "$first" ] || first=$repo
        if hv_is_official_repo "$repo"; then
            printf '%s\n' "$repo"
            return 0
        fi
    done < <(hv_package_repos "$package")
    if [ -n "$first" ]; then
        printf '%s\n' "$first"
        return 0
    fi
    printf 'unavailable\n'
    return 1
}

hv_record_source() {
    local package=$1 source=$2 feature=$3 temp
    mkdir -p "$HV_STATE_HOME"
    touch "$HV_SOURCE_LOG"
    temp=$(mktemp "$HV_STATE_HOME/.package-sources.XXXXXX")
    awk -F '\t' -v p="$package" '$1 != p' "$HV_SOURCE_LOG" > "$temp"
    printf '%s\t%s\t%s\n' "$package" "$source" "$feature" >> "$temp"
    sort -o "$temp" "$temp"
    mv -f "$temp" "$HV_SOURCE_LOG"
}

hv_source_recorded() {
    local package=$1
    [ -s "$HV_SOURCE_LOG" ] && awk -F '\t' -v p="$package" '$1 == p {found=1} END {exit !found}' "$HV_SOURCE_LOG"
}

hv_notification_backend() {
    local backend=
    if [ -r "$HV_NOTIFICATION_STATE" ]; then
        IFS= read -r backend < "$HV_NOTIFICATION_STATE" || true
    fi
    case "$backend" in
        quickshell|swaync|mako) printf '%s\n' "$backend" ;;
        *) return 1 ;;
    esac
}

hv_copr_enabled() {
    local project=$1 normalized
    normalized=${project//\//:}
    hv_enabled_repo_ids | grep -Fq ":$normalized"
}

hv_copr_repo_for_package() {
    local package=$1 project=$2 normalized repo
    normalized=${project//\//:}
    while IFS= read -r repo; do
        case "$repo" in
            *":$normalized") printf '%s\n' "$repo"; return 0 ;;
        esac
    done < <(hv_package_repos "$package")
    return 1
}

hv_root() {
    if [ "${HYPRVEIL_NO_SUDO:-0}" = 1 ] || [ "${EUID:-$(id -u)}" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

hv_enable_copr() {
    local project=$1 reason=$2
    if hv_copr_enabled "$project"; then
        hv_ok "COPR $project is already enabled; no repository change needed"
        return 0
    fi

    printf '\nCOPR fallback requested: %s\nReason: %s\n' "$project" "$reason"
    printf 'Fedora official repositories were probed first and do not provide the affected package(s).\n'
    if ! hv_confirm "Enable COPR $project?"; then
        hv_warn "declined COPR $project; repository configuration was not changed"
        return 1
    fi
    hv_root "${HYPRVEIL_DNF:-dnf}" copr enable -y "$project"
}

hv_official_repo_args() {
    local repo found=0
    while IFS= read -r repo; do
        if hv_is_official_repo "$repo"; then
            printf '%s\n' "--enable-repo=$repo"
            found=1
        fi
    done < <(hv_enabled_repo_ids)
    [ "$found" -eq 1 ]
}

hv_install_from_repos() {
    local extra_repo=$1
    shift
    local -a args=(-y '--disable-repo=*')
    local arg
    while IFS= read -r arg; do
        [ -n "$arg" ] && args+=("$arg")
    done < <(hv_official_repo_args || true)
    if [ -n "$extra_repo" ] && ! hv_is_official_repo "$extra_repo"; then
        args+=("--enable-repo=$extra_repo")
    fi
    args+=(install "$@")
    hv_root "${HYPRVEIL_DNF:-dnf}" "${args[@]}"
}

# Install a group using official repositories first. A named COPR is considered
# only for packages missing from official Fedora repositories.
# Usage: hv_install_group required|optional "feature" "copr/project or -" packages...
hv_install_group() {
    local importance=$1 feature=$2 copr=$3
    shift 3
    local package source
    local -a official=() fallback=() still_missing=()

    hv_section "Package source probe" "$feature"
    printf '  %-32s %-18s %s\n' "Package" "Source" "Status"
    printf '  %-32s %-18s %s\n' "-------" "------" "------"
    for package in "$@"; do
        source=$(hv_package_source "$package" || true)
        if hv_is_official_repo "$source"; then
            printf '  %-32s %-18s %s\n' "$package" "$source" "$(hv_style '1;32' official)"
            official+=("$package")
        else
            printf '  %-32s %-18s %s\n' "$package" "-" "$(hv_style '1;33' "needs fallback")"
            fallback+=("$package")
        fi
    done

    if [ "${#official[@]}" -gt 0 ] && hv_confirm "Install official Fedora packages for $feature?"; then
        hv_note "Installing from official Fedora repositories: ${official[*]}"
        hv_install_from_repos "" "${official[@]}"
        for package in "${official[@]}"; do
            source=$(hv_package_source "$package" || true)
            hv_record_source "$package" "$source" "$feature"
        done
        hv_ok "Recorded official package sources for $feature"
    fi

    [ "${#fallback[@]}" -gt 0 ] || return 0
    if [ "$copr" = - ]; then
        for package in "${fallback[@]}"; do
            hv_record_source "$package" unavailable "$feature"
            if [ "$importance" = optional ]; then
                hv_warn "$package unavailable: only optional feature '$feature' will remain disabled"
            else
                hv_bad "$package unavailable: required feature '$feature' cannot start"
            fi
        done
        [ "$importance" = optional ]
        return
    fi

    if ! hv_enable_copr "$copr" "$feature requires packages unavailable from enabled official Fedora repositories"; then
        for package in "${fallback[@]}"; do
            hv_record_source "$package" unavailable "$feature"
        done
        [ "$importance" = optional ] && return 0
        hv_bad "required feature '$feature' cannot be installed without its missing packages"
        return 1
    fi

    for package in "${fallback[@]}"; do
        source=$(hv_copr_repo_for_package "$package" "$copr" || true)
        if [ -z "$source" ]; then
            still_missing+=("$package")
            hv_record_source "$package" unavailable "$feature"
        else
            if hv_confirm "Install $package from $source?"; then
                hv_note "Installing $package from $source"
                hv_install_from_repos "$source" "$package"
                hv_record_source "$package" "$source" "$feature"
                hv_ok "Recorded $package source: $source"
            else
                hv_record_source "$package" declined "$feature"
            fi
        fi
    done
    if [ "${#still_missing[@]}" -gt 0 ]; then
        hv_warn "unavailable after enabling $copr: ${still_missing[*]}"
        [ "$importance" = optional ]
    fi
}

hv_new_backup_dir() {
    local stamp dir suffix=0
    stamp=$(date +%Y%m%d-%H%M%S)
    dir="$HV_STATE_HOME/backups/$stamp"
    while [ -e "$dir" ]; do
        suffix=$((suffix + 1))
        dir="$HV_STATE_HOME/backups/$stamp-$suffix"
    done
    mkdir -p "$dir"
    printf '%s\n' "$dir"
}

hv_backup_item() {
    local source=$1 backup=$2 label=${3:-$(basename "$1")}
    [ -e "$source" ] || return 0
    mkdir -p "$backup"
    cp -a "$source" "$backup/$label"
}

# Replace only Hyprveil-managed trees. Existing targets are backed up first,
# replacement removes stale managed files, and persistent state remains outside
# the config tree. User wallpaper files are explicitly carried forward, while the
# repository's bundled wallpaper is installed as an always-available fallback.
hv_deploy_configs() {
    local backup staged target name starship_tmp backend other single
    local -a names=(hypr waybar kitty rofi wlogout gtk-3.0 gtk-4.0 quickshell fontconfig)
    # quickshell is deployed unconditionally, like waybar, and is deliberately
    # NOT in all_backends even though it is selectable in
    # 07-select-notification-backend.sh. Everything in all_backends that is not
    # the active choice gets REMOVED below, so listing it here would delete the
    # shell's config on every upgrade that selected a different backend. What
    # the selection decides is whether the daemon launches, not whether its
    # config exists — the same split waybar has always had.
    # ags is retired and can no longer be selected, so it is always "inactive"
    # and its config is always removed. It stays in this list precisely for that:
    # dropping it would strand ~/.config/ags on every machine that ever ran the
    # AGS backend, with nothing left to clean it up.
    local -a all_backends=(ags swaync mako) inactive_backends=()
    backend=$(hv_notification_backend || printf 'quickshell\n')
    # quickshell is already deployed unconditionally above; appending it again
    # would stage, back up, and replace the same tree twice and leave a spurious
    # entry in the backup directory.
    local already=0 existing
    for existing in "${names[@]}"; do
        [ "$existing" = "$backend" ] && already=1
    done
    [ "$already" -eq 1 ] || names+=("$backend")
    for other in "${all_backends[@]}"; do
        [ "$other" = "$backend" ] || inactive_backends+=("$other")
    done
    # Every source tree is verified before anything is removed. Each target is
    # deleted just before its replacement is moved into place, so a source that
    # does not exist — a misresolved HV_REPO, an incomplete checkout — would
    # otherwise delete a working configuration and install nothing in its place.
    # The copy failing is not enough to prevent that on its own: cp reports the
    # error and the loop carries on to the rm.
    for name in "${names[@]}"; do
        if [ ! -d "$HV_REPO/config/$name" ]; then
            hv_bad "source tree missing: $HV_REPO/config/$name"
            hv_bad "refusing to deploy; the existing configuration is untouched"
            return 1
        fi
    done
    for single in starship.toml starship.toml.in; do
        if [ ! -f "$HV_REPO/config/$single" ]; then
            hv_bad "source file missing: $HV_REPO/config/$single"
            hv_bad "refusing to deploy; the existing configuration is untouched"
            return 1
        fi
    done

    mkdir -p "$HV_CONFIG_HOME"
    backup=$(hv_new_backup_dir)

    for name in "${names[@]}"; do
        target="$HV_CONFIG_HOME/$name"
        staged=$(mktemp -d "$HV_CONFIG_HOME/.hyprveil-$name.XXXXXX")
        if ! cp -a "$HV_REPO/config/$name/." "$staged/"; then
            rm -rf "$staged"
            hv_bad "could not stage $name from $HV_REPO/config/$name"
            return 1
        fi
        if [ "$name" = hypr ]; then
            if [ -f "$target/wallpaper.jpg" ]; then
                cp -a "$target/wallpaper.jpg" "$staged/wallpaper.jpg"
            fi
            cp -a "$HV_REPO/config/hypr/wallpaper-default.jpg" \
                "$staged/wallpaper-default.jpg"
        fi
        if [ -e "$target" ]; then
            mkdir -p "$backup/config"
            cp -a "$target" "$backup/config/$name"
            rm -rf "$target"
        fi
        mv "$staged" "$target"
    done

    # Only the selected notification backend's config is deployed. Remove the
    # other managed backend trees during upgrades so a stale daemon configuration
    # cannot be mistaken for the selected backend; preserve them in the same
    # timestamped backup first.
    for other in "${inactive_backends[@]}"; do
        target="$HV_CONFIG_HOME/$other"
        if [ -e "$target" ]; then
            mkdir -p "$backup/config"
            cp -a "$target" "$backup/config/$other"
            rm -rf "$target"
        fi
    done

    # starship.toml ships with its .in template so accent.sh render can rewrite
    # the prompt palette on the live system, the same way every tree-based
    # templated consumer carries its own .in. install.sh calls accent.sh render
    # right after this deploy.
    for single in starship.toml starship.toml.in; do
        target="$HV_CONFIG_HOME/$single"
        starship_tmp=$(mktemp "$HV_CONFIG_HOME/.hyprveil-${single//\//_}.XXXXXX")
        cp -a "$HV_REPO/config/$single" "$starship_tmp"
        if [ -e "$target" ]; then
            mkdir -p "$backup/config"
            cp -a "$target" "$backup/config/$single"
        fi
        mv -f "$starship_tmp" "$target"
    done
    chmod +x "$HV_CONFIG_HOME/hypr/scripts/"*.sh "$HV_CONFIG_HOME/hypr/scripts/lib/"*.sh \
        "$HV_CONFIG_HOME/waybar/scripts/"*.sh 2>/dev/null || true

    if [ -d "$backup/config" ]; then
        printf 'Existing configuration backed up to %s\n' "$backup"
    else
        rmdir "$backup" 2>/dev/null || true
    fi
    printf 'Hyprveil-managed configuration installed without merging stale files.\n'
}

hv_reload_live_session() {
    local backend joined reloaded=() skipped=()

    if ! command -v hyprctl >/dev/null 2>&1 || [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        printf 'Configs verified. Log into Hyprland, or reload the existing session manually.\n'
        return 0
    fi

    if hyprctl reload; then
        reloaded+=("Hyprland")
    else
        skipped+=("Hyprland")
        hv_warn "could not reload Hyprland"
    fi

    backend=$(hv_notification_backend || printf 'quickshell\n')
    if [ -x "$HV_CONFIG_HOME/hypr/scripts/notification-daemon.sh" ]; then
        "$HV_CONFIG_HOME/hypr/scripts/notification-daemon.sh" restart || true
        case "$backend" in
            quickshell) reloaded+=("Quickshell") ;;
            swaync) reloaded+=("SwayNC") ;;
            mako) reloaded+=("Mako") ;;
        esac
    else
        skipped+=("notification backend")
        hv_warn "notification daemon helper is unavailable"
    fi

    if [ -x "$HV_CONFIG_HOME/hypr/scripts/wallpaper.sh" ]; then
        "$HV_CONFIG_HOME/hypr/scripts/wallpaper.sh" restore || true
        reloaded+=("wallpaper")
    fi

    if [ -x "$HV_CONFIG_HOME/hypr/scripts/apply-theme.sh" ]; then
        "$HV_CONFIG_HOME/hypr/scripts/apply-theme.sh" || true
        reloaded+=("GTK/Qt theme")
    fi

    if [ "${#reloaded[@]}" -gt 0 ]; then
        joined=$(printf '%s, ' "${reloaded[@]}")
        printf 'Reloaded %s.\n' "${joined%, }"
    fi
    if [ "${#skipped[@]}" -gt 0 ]; then
        joined=$(printf '%s, ' "${skipped[@]}")
        printf 'Skipped live reload for %s; see warnings above.\n' "${joined%, }" >&2
    fi
}

# The managed config tree names Hyprveil owns under $HV_CONFIG_HOME, including
# the currently selected notification backend. Kept in sync with the list in
# hv_deploy_configs so update, rollback, and uninstall act on the same trees the
# installer deploys. starship.toml is a single file and is handled separately by
# callers.
hv_managed_names() {
    local backend name already=0
    local -a names=(hypr waybar kitty rofi wlogout gtk-3.0 gtk-4.0 quickshell fontconfig)
    backend=$(hv_notification_backend || printf 'quickshell\n')
    for name in "${names[@]}"; do
        [ "$name" = "$backend" ] && already=1
    done
    [ "$already" -eq 1 ] || names+=("$backend")
    printf '%s\n' "${names[@]}"
}

# Notification backend trees Hyprveil may have deployed in the past that are not
# the active choice. Used by uninstall to clean up inactive and retired backends.
hv_inactive_backend_names() {
    local backend other
    backend=$(hv_notification_backend || printf 'quickshell\n')
    for other in ags swaync mako; do
        [ "$other" = "$backend" ] || printf '%s\n' "$other"
    done
}

hv_should_keep_managed_name() {
    local candidate=$1 keep
    for keep in ${HYPRVEIL_KEEP_MANAGED_NAMES:-}; do
        [ "$candidate" = "$keep" ] && return 0
    done
    return 1
}

# Print a read-only summary of what a deploy from $HV_REPO/config would change in
# the live config home, without touching anything. One line per managed tree:
# "new", "unchanged", or "changed (N file(s) differ)". Returns 0 if any tree
# would change, 1 if the deployed configuration already matches the repository.
hv_preview_config_changes() {
    local name target differ changed=0
    local -a names
    mapfile -t names < <(hv_managed_names)
    names+=("starship.toml" "starship.toml.in")
    printf 'Pending changes from %s:\n' "$HV_REPO/config"
    for name in "${names[@]}"; do
        local source="$HV_REPO/config/$name"
        target="$HV_CONFIG_HOME/$name"
        if [ ! -e "$source" ]; then
            continue
        fi
        if [ ! -e "$target" ]; then
            printf '  new       %s\n' "$name"
            changed=1
            continue
        fi
        # Only repository-sourced files that are missing or different in the
        # deployment count as pending changes. Files that exist only in the
        # deployment — the injected default wallpaper, user wallpaper, and
        # generated accent/token fragments — are ignored so an unchanged
        # checkout reports nothing to do.
        differ=$(diff -rq "$source" "$target" 2>/dev/null \
            | grep -c -e 'differ$' -e "Only in $source" || true)
        if [ "${differ:-0}" -eq 0 ]; then
            printf '  unchanged %s\n' "$name"
        else
            printf '  changed   %s (%s path(s) differ)\n' "$name" "$differ"
            changed=1
        fi
    done
    [ "$changed" -eq 1 ]
}

# List timestamped backup snapshots, newest first, one per line as
# "<name>\t<summary>" where summary describes the payload kinds present.
hv_list_backups() {
    local dir base summary
    local root="$HV_STATE_HOME/backups"
    [ -d "$root" ] || return 0
    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        base=$(basename "$dir")
        summary=""
        [ -d "$dir/config" ] && summary+="config "
        [ -d "$dir/system-config" ] && summary+="system-config "
        [ -d "$dir/system-themes" ] && summary+="system-themes "
        [ -n "$summary" ] || summary="empty"
        printf '%s\t%s\n' "$base" "${summary% }"
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
}

# Restore the config payload of a saved snapshot directory into the live config
# home. Current trees are backed up to a fresh timestamped snapshot first, then
# replaced atomically per tree. Returns 1 if the snapshot has no config payload.
hv_restore_backup() {
    local snapshot=$1 fresh item base target staged
    if [ ! -d "$snapshot/config" ]; then
        hv_bad "backup has no config payload to restore: $snapshot"
        return 1
    fi
    mkdir -p "$HV_CONFIG_HOME"
    fresh=$(hv_new_backup_dir)
    for item in "$snapshot/config"/*; do
        [ -e "$item" ] || continue
        base=$(basename "$item")
        target="$HV_CONFIG_HOME/$base"
        staged=$(mktemp -d "$HV_CONFIG_HOME/.hyprveil-restore-$base.XXXXXX")
        if ! cp -a "$item/." "$staged/" 2>/dev/null && ! cp -a "$item" "$staged/payload" 2>/dev/null; then
            rm -rf "$staged"
            hv_bad "could not stage restore of $base from $snapshot"
            return 1
        fi
        if [ -e "$target" ]; then
            mkdir -p "$fresh/config"
            cp -a "$target" "$fresh/config/$base"
            rm -rf "$target"
        fi
        if [ -e "$staged/payload" ] && [ ! -d "$item" ]; then
            mv -f "$staged/payload" "$target"
            rm -rf "$staged"
        else
            mv "$staged" "$target"
        fi
    done
    if [ -d "$fresh/config" ]; then
        printf 'Pre-restore configuration backed up to %s\n' "$fresh"
    else
        rmdir "$fresh" 2>/dev/null || true
    fi
    printf 'Restored configuration from %s\n' "$snapshot"
}

# Back up and remove every Hyprveil-managed user config tree, including inactive
# and retired notification backend trees and starship.toml. Persistent state
# under $HV_STATE_HOME is never touched here. Prints a one-line summary and the
# path of the backup snapshot it wrote.
hv_remove_managed_config() {
    local backup name target removed=0
    local -a names
    mapfile -t names < <(hv_managed_names)
    mapfile -t -O "${#names[@]}" names < <(hv_inactive_backend_names)
    names+=("starship.toml" "starship.toml.in")
    backup=$(hv_new_backup_dir)
    for name in "${names[@]}"; do
        hv_should_keep_managed_name "$name" && continue
        target="$HV_CONFIG_HOME/$name"
        [ -e "$target" ] || continue
        mkdir -p "$backup/config"
        cp -a "$target" "$backup/config/$name"
        rm -rf "$target"
        removed=$((removed + 1))
    done
    if [ "$removed" -gt 0 ]; then
        printf 'Removed %s managed config tree(s); backup saved to %s\n' "$removed" "$backup"
    else
        rmdir "$backup" 2>/dev/null || true
        printf 'No Hyprveil-managed config trees were present to remove.\n'
    fi
}
