#!/usr/bin/bash
# Build the Qubes HUD i3 binary from pinned, verified sources.
set -euo pipefail

readonly I3_VERSION="4.25.1"
readonly QUBES_I3_COMMIT="40bb085eec2b17b49bd18e3fb9315b575a9c53cc"
readonly SOURCE_DATE_EPOCH_VALUE="1770581259"
readonly I3_TARBALL_SHA512="10d44f7efcfb23089edf5ec9783ddd3b9dca5592f4d5b101ec7158cd75ec73d917e3025250968c1c8e2d44c64d749855000a07b16059c582c1e80b1220ac7c81"
readonly QUBES_PATCH_SHA256="8dadd57d223d3df5df313807b7abb89c384ca313bb028e3a41b73ffe39766461"
readonly HUD_PATCH_SHA256="f0a45e0f487a8731cfceb71b7713fc29fdd3cf21a9cb23ffa2f184d2626c1226"

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"
output_path="${1:-${repo_dir}/salt/qubes_gui/hud/files/i3-hud}"

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "This pinned artifact is supported only on x86_64." >&2
    exit 1
fi

for required_command in curl sha512sum sha256sum tar git meson rpm gcc strip readelf install; do
    if ! command -v "${required_command}" >/dev/null 2>&1; then
        echo "Missing build command: ${required_command}" >&2
        exit 1
    fi
done

build_root="$(mktemp -d -t qubes-hud-i3.XXXXXXXX)"
cleanup() {
    rm -rf -- "${build_root}"
}
trap cleanup EXIT

tarball="${build_root}/i3-${I3_VERSION}.tar.xz"
qubes_patch="${build_root}/0001-qubes-i3.patch"
source_dir="${build_root}/i3-${I3_VERSION}"
build_dir="${source_dir}/build-hud"

env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
    curl --fail --location --proto '=https' --tlsv1.2 \
    --output "${tarball}" "https://i3wm.org/downloads/i3-${I3_VERSION}.tar.xz"
printf '%s  %s\n' "${I3_TARBALL_SHA512}" "${tarball}" | sha512sum --check --strict -

env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
    curl --fail --location --proto '=https' --tlsv1.2 \
    --output "${qubes_patch}" \
    "https://raw.githubusercontent.com/QubesOS/qubes-desktop-linux-i3/${QUBES_I3_COMMIT}/0001-Show-qubes-domain-in-configurable-colored-borders.patch"
printf '%s  %s\n' "${QUBES_PATCH_SHA256}" "${qubes_patch}" | sha256sum --check --strict -
printf '%s  %s\n' "${HUD_PATCH_SHA256}" \
    "${script_dir}/0002-qubes-hud-trusted-label-badge.patch" | sha256sum --check --strict -

tar --extract --file "${tarball}" --directory "${build_root}"
(
    cd "${source_dir}"
    git apply --check "${qubes_patch}"
    git apply "${qubes_patch}"
    git apply --check "${script_dir}/0002-qubes-hud-trusted-label-badge.patch"
    git apply "${script_dir}/0002-qubes-hud-trusted-label-badge.patch"
)

fedora_cflags="$(rpm --eval '%{build_cflags}')"
fedora_ldflags="$(rpm --eval '%{build_ldflags}')"
if [[ "${fedora_cflags}" == *'%{build_cflags}'* || "${fedora_ldflags}" == *'%{build_ldflags}'* ]]; then
    echo "Fedora RPM hardening macros are unavailable." >&2
    exit 1
fi

export LC_ALL=C
export TZ=UTC
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH_VALUE}"
export CFLAGS="${fedora_cflags} -ffile-prefix-map=${build_root}=/usr/src/debug/i3-hud-${I3_VERSION} -fdebug-prefix-map=${build_root}=/usr/src/debug/i3-hud-${I3_VERSION}"
export LDFLAGS="${fedora_ldflags}"

meson setup "${build_dir}" "${source_dir}" --buildtype=release
meson compile -C "${build_dir}" './i3:executable'
strip --strip-unneeded "${build_dir}/i3"

file_description="$(file -b "${build_dir}/i3")"
if [[ "${file_description}" != *"pie executable"* ]]; then
    echo "Refusing non-PIE artifact: ${file_description}" >&2
    exit 1
fi
readelf -lW "${build_dir}/i3" | grep -q 'GNU_RELRO'
readelf -dW "${build_dir}/i3" | grep -q 'BIND_NOW'
readelf -dW "${build_dir}/i3" | grep -q 'PIE'

install -Dm0755 "${build_dir}/i3" "${output_path}"
sha256sum "${output_path}"
"${output_path}" --version
