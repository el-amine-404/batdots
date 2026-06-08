#!/usr/bin/env bash
# libaom -- AV1 reference codec (encode + decode). Required by libheif and libavif.
# Source: Google Cloud Storage (no GitHub releases). Version fetched via GCS JSON API.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libaom"
build::ensure_pkg_config_path

VERSION=$(source::fetch_latest "LIBAOM")

build::already_installed "aom" "$VERSION" && exit 0

URL="https://storage.googleapis.com/aom-releases/libaom-${VERSION}.tar.gz"
src_dir=$(build::fetch_tarball "libaom" "$VERSION" "$URL")

build::cmake_install "$src_dir" \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_TESTS=OFF \
  -DENABLE_DOCS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_TOOLS=OFF

build::verify_pkgconfig "aom"
build::cleanup "libaom"
log::info "libaom ${VERSION} done"
