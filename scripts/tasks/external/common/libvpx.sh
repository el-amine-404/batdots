#!/usr/bin/env bash
# libvpx -- VP8/VP9 encoder + decoder.
# Uses a custom configure script (not autoconf), so build::make_install is not used.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libvpx"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBVPX")
build::already_installed "vpx" "$VERSION" && exit 0

src_dir=$(build::fetch_git "vpx" "https://github.com/webmproject/libvpx.git" "v${VERSION}")

(
  cd "$src_dir" || exit 1
  log::info "Configuring (libvpx custom configure)..."
  ./configure \
    --prefix="$BUILD_PREFIX" \
    --enable-shared \
    --enable-vp8 \
    --enable-vp9 \
    --enable-vp9-highbitdepth \
    --enable-multithread \
    --enable-runtime-cpu-detect \
    --disable-install-docs \
    --disable-install-srcs > /dev/null

  log::info "Compiling... ($(build::nproc) cores)"
  make -j "$(build::nproc)"
  log::info "Installing..."
  $SUDO_CMD make install
  $SUDO_CMD ldconfig
)

build::verify_pkgconfig "vpx"
log::info "libvpx ${VERSION} done"
