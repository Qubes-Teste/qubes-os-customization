#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_root="$repo_root/salt/qubes_gui"
target_root=/srv/user_salt/qubes_gui

for formula in i3 hud; do
    if [[ ! -f "$source_root/$formula/init.sls" ]]; then
        printf 'Formula source not found: %s\n' "$source_root/$formula" >&2
        exit 1
    fi
done

if [[ ${EUID} -eq 0 ]]; then
    as_root=()
else
    as_root=(sudo)
fi

"${as_root[@]}" qubesctl state.sls qubes.user-dirs

for formula in i3 hud; do
    while IFS= read -r -d '' source_file; do
        relative_path=${source_file#"$source_root/"}
        target_file="$target_root/$relative_path"
        "${as_root[@]}" install -d -o root -g root -m 0750 "$(dirname -- "$target_file")"
        "${as_root[@]}" install -o root -g root -m 0640 "$source_file" "$target_file"
    done < <(find "$source_root/$formula" -type f -print0)
done

printf 'Salt formulas synchronized to %s\n' "$target_root"
printf '%s\n' 'Dry-run with:'
printf '%s\n' '  sudo qubesctl state.sls qubes_gui.i3 saltenv=user test=True'
printf '%s\n' '  sudo qubesctl state.sls qubes_gui.hud saltenv=user test=True'
