#!/usr/bin/env bash
# libopus -- Opus audio codec (encode + decode).
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libopus"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBOPUS")
build::already_installed "opus" "$VERSION" && exit 0

src_dir=$(build::fetch_git "opus" "https://github.com/xiph/opus.git" "v${VERSION}")

build::make_install "$src_dir" \
  --enable-shared \
  --disable-doc \
  --disable-extra-programs

build::verify_pkgconfig "opus"
log::info "libopus ${VERSION} done"
