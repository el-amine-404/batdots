#!/usr/bin/env bash
# libwebp -- WebP encode + decode. Required by libheif and ImageMagick.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libwebp"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBWEBP")
build::already_installed "libwebp" "$VERSION" && exit 0

src_dir=$(build::fetch_git "webp" "https://github.com/webmproject/libwebp.git" "v${VERSION}")

build::cmake_install "$src_dir" \
  -DBUILD_SHARED_LIBS=ON \
  -DWEBP_BUILD_ANIM_UTILS=OFF \
  -DWEBP_BUILD_CWEBP=ON \
  -DWEBP_BUILD_DWEBP=ON \
  -DWEBP_ENABLE_SIMD=ON \
  -DWEBP_BUILD_EXTRAS=OFF

build::verify_pkgconfig "libwebp"
build::cleanup "webp"
log::info "libwebp ${VERSION} done"
