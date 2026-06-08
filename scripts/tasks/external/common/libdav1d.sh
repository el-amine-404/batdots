#!/usr/bin/env bash
# libdav1d -- Fast AV1 decoder by VideoLAN. Used by ffmpeg and libavif.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libdav1d"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBDAV1D")
build::already_installed "dav1d" "$VERSION" && exit 0

src_dir=$(build::fetch_git "dav1d" "https://github.com/videolan/dav1d.git" "${VERSION}")

build::meson_install "$src_dir" \
  -Denable_tests=false \
  -Denable_docs=false \
  -Denable_examples=false

build::verify_pkgconfig "dav1d"
log::info "libdav1d ${VERSION} done"
