#!/usr/bin/env bash
# mpv -- Video player. Best-in-class codec support via the ffmpeg/libav stack.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-mpv"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "MPV")

# ... deps check ...
for dep in libplacebo libass luajit uchardet libdisplay-info xpresent libarchive; do
  if ! pkg-config --exists "$dep" 2> /dev/null; then
    log::error "Missing dependency: ${dep} -- run its build script or install system dev headers first"
    exit 1
  fi
done

build::binary_already_installed "mpv" "$VERSION" \
  'mpv --version | grep -oP "mpv \K[0-9.v-]+"' && exit 0

src_dir=$(build::fetch_git "mpv" "https://github.com/mpv-player/mpv.git" "v${VERSION}")

if build::git_is_current "mpv" "mpv"; then
  log::info "mpv already up to date -- skipping"
  exit 0
fi

build::meson_install "$src_dir" \
  -Dlibmpv=true \
  -Dgl=enabled \
  -Ddrm=enabled \
  -Dwayland=disabled \
  -Dx11=enabled \
  -Dmanpage-build=disabled

build::git_mark_built "mpv"
hash -r 2> /dev/null || true

build::verify_binary "mpv"
build::cleanup "mpv"
log::info "mpv ${VERSION} done"
