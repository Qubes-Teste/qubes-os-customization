#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_root="$repo_root/salt/qubes_gui"
target_root=/srv/user_salt/qubes_gui
manifest_path="$target_root/.qubes-gui-sync-manifest-v1"

formulas=(i3 hud guest_hud templates)
required_entries=(
    i3/init.sls
    i3/rollback.sls
    hud/init.sls
    hud/rollback.sls
    guest_hud/init.sls
    guest_hud/map.jinja
    guest_hud/rollback.sls
    templates/hud.sls
)

fail() {
    printf 'Salt formula sync refused: %s\n' "$1" >&2
    exit 1
}

safe_relative_path() {
    local candidate=$1

    [[ -n $candidate && $candidate != /* ]] || return 1
    [[ $candidate != *$'\n'* && $candidate != *$'\t'* ]] || return 1
    [[ $candidate =~ ^(i3|hud|guest_hud|templates)/[A-Za-z0-9._/-]+$ ]] ||
        return 1
    case "/$candidate/" in
        *'//'*|*'/./'*|*'/../'*) return 1 ;;
    esac
    case "$candidate" in
        i3/*|hud/*|guest_hud/*|templates/*) return 0 ;;
        *) return 1 ;;
    esac
}

check_target_parents() {
    local relative_path=$1
    local parent_path=${relative_path%/*}
    local current_path=$target_root
    local component
    local -a components=()

    IFS=/ read -r -a components <<<"$parent_path"
    for component in "${components[@]}"; do
        current_path="$current_path/$component"
        if "${as_root[@]}" test -L "$current_path"; then
            fail "target parent is a symlink: $current_path"
        fi
        if "${as_root[@]}" test -e "$current_path" &&
                ! "${as_root[@]}" test -d "$current_path"; then
            fail "target parent is not a directory: $current_path"
        fi
    done
}

for formula in "${formulas[@]}"; do
    if [[ ! -d "$source_root/$formula" ]]; then
        fail "formula directory not found: $source_root/$formula"
    fi
done

for entry in "${required_entries[@]}"; do
    if [[ ! -f "$source_root/$entry" || -L "$source_root/$entry" ]]; then
        fail "required regular source file not found: $source_root/$entry"
    fi
done

if [[ ${EUID} -eq 0 ]]; then
    as_root=()
else
    as_root=(sudo)
fi

new_manifest=$(mktemp)
cleanup() {
    rm -f -- "$new_manifest"
}
trap cleanup EXIT

printf '%s\n' '# qubes-gui-sync-manifest-v1' >"$new_manifest"
declare -a source_files=()
declare -a relative_paths=()
declare -A current_paths=()

for formula in "${formulas[@]}"; do
    while IFS= read -r -d '' source_file; do
        relative_path=${source_file#"$source_root/"}
        safe_relative_path "$relative_path" ||
            fail "unsafe source path: $relative_path"
        checksum=$(/usr/bin/sha256sum -- "$source_file")
        checksum=${checksum%% *}
        source_files+=("$source_file")
        relative_paths+=("$relative_path")
        current_paths["$relative_path"]=1
        printf '%s\t%s\n' "$checksum" "$relative_path" >>"$new_manifest"
    done < <(find "$source_root/$formula" -type f -print0 | sort -z)
done

"${as_root[@]}" qubesctl state.sls qubes.user-dirs

if "${as_root[@]}" test -L "$target_root" ||
        ! "${as_root[@]}" test -d "$target_root"; then
    fail "Salt target root is not a real directory: $target_root"
fi

for relative_path in "${relative_paths[@]}"; do
    check_target_parents "$relative_path"
done

declare -A previous_hashes=()
declare -a stale_paths=()
if "${as_root[@]}" test -e "$manifest_path" ||
        "${as_root[@]}" test -L "$manifest_path"; then
    if "${as_root[@]}" test -L "$manifest_path" ||
            ! "${as_root[@]}" test -f "$manifest_path"; then
        fail "existing manifest is not an owned regular file: $manifest_path"
    fi

    manifest_contents=$("${as_root[@]}" sed -n 'p' "$manifest_path")
    line_number=0
    while IFS=$'\t' read -r stored_hash stored_path extra; do
        ((line_number += 1))
        if ((line_number == 1)); then
            [[ $stored_hash == '# qubes-gui-sync-manifest-v1' &&
                -z $stored_path && -z $extra ]] ||
                fail "unrecognized manifest format: $manifest_path"
            continue
        fi
        [[ $stored_hash =~ ^[[:xdigit:]]{64}$ && -z $extra ]] ||
            fail "malformed manifest entry on line $line_number"
        safe_relative_path "$stored_path" ||
            fail "unsafe manifest path on line $line_number: $stored_path"
        [[ ! ${previous_hashes[$stored_path]+present} ]] ||
            fail "duplicate manifest path: $stored_path"
        previous_hashes["$stored_path"]=$stored_hash
    done <<<"$manifest_contents"

    for stored_path in "${!previous_hashes[@]}"; do
        [[ ! ${current_paths[$stored_path]+present} ]] || continue
        check_target_parents "$stored_path"
        stale_target="$target_root/$stored_path"
        if "${as_root[@]}" test -L "$stale_target"; then
            fail "stale managed path became a symlink: $stale_target"
        fi
        if "${as_root[@]}" test -e "$stale_target"; then
            "${as_root[@]}" test -f "$stale_target" ||
                fail "stale managed path is not a regular file: $stale_target"
            installed_checksum=$("${as_root[@]}" /usr/bin/sha256sum -- "$stale_target")
            installed_checksum=${installed_checksum%% *}
            [[ $installed_checksum == "${previous_hashes[$stored_path]}" ]] ||
                fail "stale managed file was locally modified: $stale_target"
            stale_paths+=("$stored_path")
        fi
    done
fi

for index in "${!source_files[@]}"; do
    source_file=${source_files[$index]}
    relative_path=${relative_paths[$index]}
    target_file="$target_root/$relative_path"
    if "${as_root[@]}" test -L "$target_file"; then
        fail "target path is a symlink: $target_file"
    fi
    if "${as_root[@]}" test -e "$target_file" &&
            ! "${as_root[@]}" test -f "$target_file"; then
        fail "target path is not a regular file: $target_file"
    fi
    "${as_root[@]}" install -d -o root -g root -m 0750 "$(dirname -- "$target_file")"
    "${as_root[@]}" install -o root -g root -m 0640 "$source_file" "$target_file"
done

for stored_path in "${stale_paths[@]}"; do
    "${as_root[@]}" rm -f -- "$target_root/$stored_path"
done

"${as_root[@]}" install -o root -g root -m 0640 \
    "$new_manifest" "$manifest_path"

printf 'Salt formulas synchronized to %s\n' "$target_root"
printf '%s\n' 'Dry-run with:'
printf '%s\n' '  sudo qubesctl state.sls qubes_gui.i3 saltenv=user test=True'
printf '%s\n' '  sudo qubesctl state.sls qubes_gui.hud saltenv=user test=True'
printf '%s\n' '  sudo qubesctl --skip-dom0 --targets=NAME state.sls qubes_gui.guest_hud saltenv=user test=True'
