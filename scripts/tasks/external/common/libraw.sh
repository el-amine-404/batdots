#!/usr/bin/env bash
# LibRaw -- RAW camera file decoder (CR2, NEF, ARW, DNG, RW2...).
# Required by ImageMagick for RAW support.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libraw"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBRAW")
build::already_installed "libraw" "$VERSION" && exit 0

# LibRaw GitHub tarballs lack a pre-generated configure -- autoreconf handles it
URL="https://github.com/LibRaw/LibRaw/archive/refs/tags/${VERSION}.tar.gz"
src_dir=$(build::fetch_tarball "libraw" "$VERSION" "$URL")

build::make_install "$src_dir" \
  --enable-shared \
  --disable-examples

build::verify_pkgconfig "libraw"
log::info "LibRaw ${VERSION} done"
