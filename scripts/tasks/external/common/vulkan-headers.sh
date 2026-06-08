#!/usr/bin/env bash
# vulkan-headers -- Vulkan header files.
# Required by modern FFmpeg and mpv versions. Distro headers are often too old.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-vulkan-headers"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "VULKAN_HEADERS")

# Verify by checking for a specific recent Vulkan type in the headers
if [[ -f "/usr/local/include/vulkan/vulkan_core.h" ]]; then
  if grep -q "VkVideoCodecOperationFlagBitsKHR" "/usr/local/include/vulkan/vulkan_core.h"; then
    log::info "Vulkan-Headers ${VERSION} or compatible already installed -- skipping"
    exit 0
  fi
fi

src_dir=$(build::fetch_git "vulkan-headers" "https://github.com/KhronosGroup/Vulkan-Headers.git" "v${VERSION}")

build::cmake_install "$src_dir"

build::cleanup "vulkan-headers"
log::info "vulkan-headers ${VERSION} done"
