#!/usr/bin/env bash

set -euo pipefail

usage() {
    printf 'Usage: %s SOURCE_TEMPLATE TARGET_TEMPLATE\n' "$0" >&2
    exit 2
}

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

valid_qube_name() {
    local name=$1
    local name_pattern='^[A-Za-z][A-Za-z0-9_.-]{0,30}$'

    [[ $name =~ $name_pattern ]] || return 1
    [[ $name != Domain-0 && $name != none && $name != default ]] || return 1
    [[ $name != *-dm ]]
}

[[ $# -eq 2 ]] || usage
source_template=$1
target_template=$2

valid_qube_name "$source_template" ||
    die "invalid Qubes source name: $source_template"
valid_qube_name "$target_template" ||
    die "invalid Qubes target name: $target_template"
[[ $source_template != "$target_template" ]] ||
    die 'source and target TemplateVM names must differ'

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

if [[ ${EUID} -eq 0 ]]; then
    as_root=()
else
    as_root=(sudo)
fi

pillar_json=$(printf \
    '{"qubes_gui":{"templates":{"hud":{"source":"%s","target":"%s"}}}}' \
    "$source_template" "$target_template")

"$repo_root/scripts/sync-salt-formula.sh"

"${as_root[@]}" qubesctl state.show_sls qubes_gui.templates.hud \
    saltenv=user pillar="$pillar_json" >/dev/null
"${as_root[@]}" qubesctl state.sls qubes_gui.templates.hud \
    saltenv=user pillar="$pillar_json"

"${as_root[@]}" qubesctl --skip-dom0 --targets="$target_template" \
    state.show_sls qubes_gui.guest_hud saltenv=user >/dev/null
"${as_root[@]}" qubesctl --skip-dom0 --targets="$target_template" \
    state.sls qubes_gui.guest_hud saltenv=user test=True
"${as_root[@]}" qubesctl --skip-dom0 --targets="$target_template" \
    state.sls qubes_gui.guest_hud saltenv=user

"${as_root[@]}" /usr/bin/qvm-check --quiet --template "$target_template" ||
    die "provisioned target is not a TemplateVM: $target_template"
if "${as_root[@]}" /usr/bin/qvm-check --quiet --running "$target_template" ||
        "${as_root[@]}" /usr/bin/qvm-check --quiet --paused "$target_template"; then
    "${as_root[@]}" /usr/bin/qvm-shutdown --wait "$target_template" ||
        die "theme applied, but target did not shut down cleanly: $target_template"
fi
if "${as_root[@]}" /usr/bin/qvm-check --quiet --running "$target_template" ||
        "${as_root[@]}" /usr/bin/qvm-check --quiet --paused "$target_template"; then
    die "theme applied, but target is still not halted: $target_template"
fi

printf 'HUD TemplateVM ready and halted: %s\n' "$target_template"
