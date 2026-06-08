#!/usr/bin/env bash
# libx265 -- H.265/HEVC encoder. Required by libheif for HEIC encoding.
# Note: CMakeLists.txt lives in the source/ subdirectory of the tarball.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libx265"
build::ensure_pkg_config_path

VERSION=$(source::fetch_latest "LIBX265")

build::already_installed "x265" "$VERSION" && exit 0

URL="https://bitbucket.org/multicoreware/x265_git/downloads/x265_${VERSION}.tar.gz"
src_dir=$(build::fetch_tarball "x265" "$VERSION" "$URL")

# cmake root is in source/ subdirectory
build::cmake_install "${src_dir}/source" \
  -DENABLE_SHARED=ON \
  -DENABLE_CLI=ON

build::verify_pkgconfig "x265"
log::info "libx265 ${VERSION} done"
