#!/usr/bin/env bash
# libavif -- AVIF encode + decode (AV1 Image File Format).
# Depends on: libaom, libdav1d, libsvtav1 (all Layer 1)
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libavif"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBAVIF")
build::already_installed "libavif" "$VERSION" && exit 0

# Verify dependencies
for dep in aom dav1d SvtAv1Enc; do
  if ! pkg-config --exists "$dep" 2> /dev/null; then
    log::error "Missing dependency: ${dep} -- run its build script first"
    exit 1
  fi
done

# libyuv-dev doesn't provide a .pc file on some distros (Ubuntu/Mint)
# Verify via header existence
if [[ ! -f "/usr/include/libyuv.h" ]]; then
  log::error "Missing dependency: libyuv (header not found at /usr/include/libyuv.h)"
  exit 1
fi

src_dir=$(build::fetch_git "libavif" "https://github.com/AOMediaCodec/libavif.git" "v${VERSION}")

build::cmake_install "$src_dir" \
  -DBUILD_SHARED_LIBS=ON \
  -DAVIF_LIBYUV=SYSTEM \
  -DAVIF_CODEC_AOM=SYSTEM \
  -DAVIF_CODEC_DAV1D=SYSTEM \
  -DAVIF_CODEC_SVT=SYSTEM \
  -DAVIF_CODEC_AOM_ENCODE=ON \
  -DAVIF_CODEC_AOM_DECODE=ON \
  -DAVIF_BUILD_APPS=ON \
  -DAVIF_BUILD_TESTS=OFF

build::verify_pkgconfig "libavif"
build::verify_binary "avifenc"
build::cleanup "libavif"
log::info "libavif ${VERSION} done"
