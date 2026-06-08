#!/usr/bin/env bash
# libjxl -- JPEG XL encode + decode.
# Requires git --recursive because GitHub tarballs omit submodules (highway, brotli).
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libjxl"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBJXL")
build::already_installed "libjxl" "$VERSION" && exit 0

src_dir=$(build::fetch_git "libjxl" "https://github.com/libjxl/libjxl.git" "v${VERSION}")

(
  cd "$src_dir" || exit 1
  log::info "Initializing essential submodules (skipping 65MB+ of testdata)..."
  # Only init what's needed for the library build
  git submodule update --init --recursive --depth 1 --jobs "$(build::nproc)" \
    third_party/highway \
    third_party/brotli \
    third_party/skcms \
    third_party/lcms
)

build::cmake_install "$src_dir" \
  -DCMAKE_CXX_FLAGS="-Wno-maybe-uninitialized" \
  -DBUILD_TESTING=OFF \
  -DJPEGXL_ENABLE_BENCHMARK=OFF \
  -DJPEGXL_ENABLE_EXAMPLES=OFF \
  -DJPEGXL_ENABLE_MANPAGES=OFF \
  -DJPEGXL_ENABLE_SJPEG=OFF \
  -DJPEGXL_ENABLE_PLUGINS=ON \
  -DBUILD_SHARED_LIBS=ON

build::verify_pkgconfig "libjxl"
build::cleanup "libjxl"
log::info "libjxl ${VERSION} done"
