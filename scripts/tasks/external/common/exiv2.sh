#!/usr/bin/env bash
# Exiv2 -- EXIF/IPTC/XMP metadata library. Required by ImageMagick.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-exiv2"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "EXIV2")
build::already_installed "exiv2" "$VERSION" && exit 0

src_dir=$(build::fetch_git "exiv2" "https://github.com/Exiv2/exiv2.git" "v${VERSION}")

build::cmake_install "$src_dir" \
  -DBUILD_SHARED_LIBS=ON \
  -DEXIV2_ENABLE_XMP=ON \
  -DEXIV2_ENABLE_BMFF=ON \
  -DEXIV2_BUILD_SAMPLES=OFF \
  -DEXIV2_BUILD_EXIV2_COMMAND=ON \
  -DEXIV2_ENABLE_NLS=OFF

build::verify_pkgconfig "exiv2"
build::cleanup "exiv2"
log::info "exiv2 ${VERSION} done"
