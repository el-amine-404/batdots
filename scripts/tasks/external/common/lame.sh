#!/usr/bin/env bash
# LAME -- MP3 encoder. Final release 3.100 (2017). Required by ffmpeg --enable-libmp3lame.
# No GitHub releases; URL is fixed to SourceForge.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-lame"
build::ensure_pkg_config_path

[[ -z "$LAME_VERSION" ]] && {
  log::error "LAME_VERSION must be set in versions.conf"
  exit 1
}
VERSION="$LAME_VERSION"

build::binary_already_installed "lame" "$VERSION" 'lame --version 2>&1 | grep -oP "version \K[0-9.]+" | head -1' && exit 0

URL="https://downloads.sourceforge.net/project/lame/lame/${VERSION}/lame-${VERSION}.tar.gz"
src_dir=$(build::fetch_tarball "lame" "$VERSION" "$URL")

build::make_install "$src_dir" \
  --enable-shared \
  --enable-nasm \
  --disable-frontend

# LAME does not ship a .pc file -- verify via the installed header
if [[ ! -f "${BUILD_PREFIX}/include/lame/lame.h" ]]; then
  log::error "Verification failed: ${BUILD_PREFIX}/include/lame/lame.h not found"
  exit 1
fi
log::info "Verified: lame/lame.h present"
log::info "lame ${VERSION} done"
