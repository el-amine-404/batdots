#!/usr/bin/env bash
# libdisplay-info -- EDID parsing library.
# Required by modern mpv (v0.41.0+) for the DRM backend.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libdisplay-info"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBDISPLAY_INFO")
build::already_installed "libdisplay-info" "$VERSION" && exit 0

src_dir=$(build::fetch_git "libdisplay-info" "https://gitlab.freedesktop.org/emersion/libdisplay-info.git" "${VERSION}")

build::meson_install "$src_dir"

build::verify_pkgconfig "libdisplay-info"
build::cleanup "libdisplay-info"
log::info "libdisplay-info ${VERSION} done"
