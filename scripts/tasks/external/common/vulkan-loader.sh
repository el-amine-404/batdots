#!/usr/bin/env bash
# vulkan-loader -- Vulkan dynamic loader library (libvulkan.so).
# Required by modern mpv (v0.41.0+) which needs loader >= 1.3.238.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-vulkan-loader"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "VULKAN_LOADER")

# Note: Distro vulkan-loader is 1.3.204. We need 1.3.238+.
build::already_installed "vulkan" "$VERSION" && exit 0

# Vulkan-Loader needs Vulkan-Headers to build
if [[ ! -f "/usr/local/include/vulkan/vulkan.h" ]]; then
  log::error "Missing dependency: Vulkan-Headers -- run its build script first"
  exit 1
fi

src_dir=$(build::fetch_git "vulkan-loader" "https://github.com/KhronosGroup/Vulkan-Loader.git" "v${VERSION}")

# We must tell CMake where to find our custom Vulkan-Headers
build::cmake_install "$src_dir" \
  -DVULKAN_HEADERS_INSTALL_DIR="/usr/local" \
  -DBUILD_WSI_WAYLAND_SUPPORT=ON \
  -DBUILD_WSI_XCB_SUPPORT=ON \
  -DBUILD_WSI_XLIB_SUPPORT=ON \
  -DBUILD_TESTS=OFF

build::verify_pkgconfig "vulkan"
build::cleanup "vulkan-loader"
log::info "vulkan-loader ${VERSION} done"
