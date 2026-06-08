#!/usr/bin/env bash
# SVT-AV1 -- Scalable Video Technology AV1 encoder. Fast AV1 encode.
# Required by libheif (SvtEnc plugin) and libavif.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libsvtav1"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBSVTAV1")
build::already_installed "SvtAv1Enc" "$VERSION" && exit 0

src_dir=$(build::fetch_git "svtav1" "https://gitlab.com/AOMediaCodec/SVT-AV1.git" "v${VERSION}")

build::cmake_install "$src_dir" \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_AVX512=OFF \
  -DBUILD_APPS=ON \
  -DCMAKE_EXE_LINKER_FLAGS="-flto=auto" \
  -DCMAKE_SHARED_LINKER_FLAGS="-flto=auto"

build::verify_pkgconfig "SvtAv1Enc"
log::info "SVT-AV1 ${VERSION} done"
