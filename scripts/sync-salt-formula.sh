#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir="$repo_root/salt/qubes_gui/i3"
target_dir=/srv/user_salt/qubes_gui/i3

if [[ ! -f "$source_dir/init.sls" ]]; then
    printf 'Formula source not found: %s\n' "$source_dir" >&2
    exit 1
fi

if [[ ${EUID} -eq 0 ]]; then
    as_root=()
else
    as_root=(sudo)
fi

"${as_root[@]}" qubesctl state.sls qubes.user-dirs
"${as_root[@]}" install -d -o root -g root -m 0750 "$target_dir/files"
"${as_root[@]}" install -o root -g root -m 0640 \
    "$source_dir/init.sls" \
    "$source_dir/rollback.sls" \
    "$target_dir/"
"${as_root[@]}" install -o root -g root -m 0640 \
    "$source_dir/files/i3-user-config" \
    "$source_dir/files/10-qubes-customization.conf.jinja" \
    "$source_dir/files/90-qubes-i3.conf" \
    "$source_dir/files/90-qubes-xfce.conf" \
    "$target_dir/files/"

printf 'Salt formula synchronized to %s\n' "$target_dir"
printf '%s\n' 'Dry-run with:'
printf '%s\n' '  sudo qubesctl state.sls qubes_gui.i3 saltenv=user test=True'
