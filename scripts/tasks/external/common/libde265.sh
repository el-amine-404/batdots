#!/usr/bin/env bash
# libde265 -- Open H.265/HEVC decode. Required by libheif for HEIC support.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libde265"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBDE265")
build::already_installed "libde265" "$VERSION" && exit 0

src_dir=$(build::fetch_git "libde265" "https://github.com/strukturag/libde265.git" "v${VERSION}")

build::cmake_install "$src_dir" \
  -DENABLE_SDL=OFF

build::verify_pkgconfig "libde265"
build::cleanup "libde265"
log::info "libde265 ${VERSION} done"
