#!/usr/bin/env bash
# rofi -- Window switcher, application launcher and dmenu replacement.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-rofi"
build::ensure_pkg_config_path

# Resolve Version
VERSION=$(build::resolve_version "ROFI")

# Idempotency check
build::binary_already_installed "rofi" "$VERSION" 'rofi -v | awk "/Version/ {print \$NF}"' && exit 0

# Ensure dependencies (distro-agnostic via generic names)
deps=(
  lib_glib lib_cairo lib_pango lib_xcb_xkb
  lib_xkbcommon lib_xkbcommon_x11 lib_xcb_util
  lib_xcb_ewmh lib_xcb_icccm lib_xcb_cursor
  lib_xcb_xinerama lib_xcb_xrm lib_xcb_randr
  lib_xcb_keysyms lib_xcb1 lib_startup_notification
  tool_flex tool_bison tool_check lib_wayland wayland-protocols
)

for d in "${deps[@]}"; do
  # Resolve generic name to native package name
  native_pkg=$(packages::resolve_name "$d" "$(packages::detect_native_package_manager)")
  if ! build::package_exists "$native_pkg"; then
    build::install_system_package "$native_pkg"
  fi
done

# Source Acquisition
# Rofi tags are usually just the version (e.g. 1.7.8)
URL="https://github.com/davatorium/rofi/releases/download/${VERSION}/rofi-${VERSION}.tar.xz"
src_dir=$(build::fetch_tarball "rofi" "$VERSION" "$URL")

# Build & Install
build::meson_install "$src_dir" \
  -Dxcb=enabled \
  -Dwayland=enabled

build::verify_binary "rofi"
build::cleanup "rofi"
log::info "rofi ${VERSION} done"
