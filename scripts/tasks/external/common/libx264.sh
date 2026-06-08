#!/usr/bin/env bash
# libx264 -- H.264/AVC encoder. Tracks the stable git branch (no version tags).
# Idempotency: skips rebuild if source HEAD matches what was last built.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libx264"
build::ensure_pkg_config_path

BRANCH="$LIBX264_VERSION" # "stable" branch from versions.conf

src_dir=$(build::fetch_git "x264" "https://code.videolan.org/videolan/x264.git" "$BRANCH")

if build::git_is_current "x264" "x264"; then
  log::info "x264 (${BRANCH}) already up to date -- skipping"
  exit 0
fi

(
  cd "$src_dir" || exit 1
  log::info "Configuring (x264 custom configure)..."
  ./configure \
    --prefix="$BUILD_PREFIX" \
    --enable-shared \
    --enable-static \
    --enable-pic \
    --enable-strip > /dev/null

  log::info "Compiling... ($(build::nproc) cores)"
  make -j "$(build::nproc)"
  log::info "Installing..."
  $SUDO_CMD make install
  $SUDO_CMD ldconfig
)

build::git_mark_built "x264"
build::verify_pkgconfig "x264"
log::info "x264 (${BRANCH}) done"
