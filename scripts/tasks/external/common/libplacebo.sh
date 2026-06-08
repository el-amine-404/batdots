#!/usr/bin/env bash
# libplacebo -- GPU-accelerated video/image rendering primitives.
# Required by modern mpv versions.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libplacebo"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBPLACEBO")

# Note: We use pkg-config to check for the source-built version.
# If the system version is 4.x but we need 6+, build::already_installed will correctly
# see the mismatch and trigger a rebuild in /usr/local.
build::already_installed "libplacebo" "$VERSION" && exit 0

# libplacebo has submodules (like glad)
src_dir=$(build::fetch_git "libplacebo" "https://github.com/haasn/libplacebo.git" "v${VERSION}" "--recursive")

# Build with Vulkan support
build::meson_install "$src_dir" \
  -Dvulkan=enabled \
  -Dshaderc=disabled \
  -Dglslang=enabled \
  -Dlcms=enabled \
  -Ddemos=false \
  -Dtests=false

build::verify_pkgconfig "libplacebo"
build::cleanup "libplacebo"
log::info "libplacebo ${VERSION} done"
