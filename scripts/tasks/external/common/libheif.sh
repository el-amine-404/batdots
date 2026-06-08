#!/usr/bin/env bash
# libheif -- HEIC/HEIF/AVIF container decoder+encoder. The key library for iPhone photos.
# Depends on: libde265, libx265, libaom, libdav1d, libsvtav1, libwebp (all Layer 1)
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libheif"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBHEIF")
build::already_installed "libheif" "$VERSION" && exit 0

# Verify all Layer 1 deps are present before attempting build
for dep in libde265 x265 aom dav1d SvtAv1Enc; do
  if ! pkg-config --exists "$dep" 2> /dev/null; then
    log::error "Missing Layer 1 dependency: ${dep} -- run its build script first"
    exit 1
  fi
done

src_dir=$(build::fetch_git "libheif" "https://github.com/strukturag/libheif.git" "v${VERSION}")

build::cmake_install "$src_dir" \
  -DBUILD_SHARED_LIBS=ON \
  -DWITH_EXAMPLES=ON \
  -DWITH_LIBDE265=ON \
  -DWITH_X265=ON \
  -DWITH_AOM_DECODER=ON \
  -DWITH_AOM_ENCODER=ON \
  -DWITH_DAV1D=ON \
  -DWITH_SvtEnc=ON \
  -DWITH_LIBSHARPYUV=ON \
  -DENABLE_PLUGIN_LOADING=ON

build::verify_pkgconfig "libheif"
build::verify_binary "heif-convert"
build::cleanup "libheif"
log::info "libheif ${VERSION} done"
