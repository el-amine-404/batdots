#!/usr/bin/env bash
# ffmpeg -- Audio/video converter with full codec support.
# Uses its own configure script (not autoconf/cmake/meson).
# Depends on all Layer 1 codec libs being installed first.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-ffmpeg"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "FFMPEG")

build::binary_already_installed "ffmpeg" "$VERSION" \
  'ffmpeg -version 2>&1 | grep -oP "ffmpeg version \K[^ ]+"' && exit 0

# Purge any system ffmpeg to prevent path/linking conflicts
build::purge_system_package "ffmpeg"
build::purge_system_package "libavcodec-extra"

# Verify critical codec deps are present
# We also check for fribidi/harfbuzz which are essential for libass (subtitles)
for dep in x264 x265 aom dav1d vpx opus libwebp SvtAv1Enc fdk-aac theora vorbis ogg fribidi harfbuzz libplacebo libvmaf; do
  if ! pkg-config --exists "$dep" 2> /dev/null; then
    log::error "Missing dependency: ${dep} -- run its build script or install system dev headers first"
    exit 1
  fi
done

src_dir=$(build::fetch_git "ffmpeg" "https://github.com/FFmpeg/FFmpeg.git" "n${VERSION}")

if build::git_is_current "ffmpeg" "ffmpeg"; then
  log::info "ffmpeg already up to date -- skipping"
  exit 0
fi

(
  cd "$src_dir" || exit 1

  log::info "Configuring ffmpeg (Alignment with Ubuntu Wiki recommendations)..."

  # Standardize on g++ for linking to ensure compatibility with all C++ delegates (like libjxl/libvmaf)
  export LD="g++"

  ./configure \
    --prefix="$BUILD_PREFIX" \
    --enable-shared \
    --enable-static \
    --enable-gpl \
    --enable-nonfree \
    --enable-version3 \
    --enable-pthreads \
    \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libtheora \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libaom \
    --enable-libdav1d \
    --enable-libsvtav1 \
    --enable-libwebp \
    --enable-libjxl \
    --enable-libfdk-aac \
    --enable-libplacebo \
    --enable-libvmaf \
    \
    --enable-libass \
    --enable-libfreetype \
    --enable-fontconfig \
    --enable-libfribidi \
    \
    --enable-vaapi \
    --enable-vdpau \
    --enable-libdrm \
    \
    --enable-gnutls \
    --enable-network \
    \
    --disable-debug \
    --disable-doc \
    --disable-ffplay \
    \
    --extra-libs="-lpthread -lm" \
    --pkg-config-flags="--static" > /dev/null

  log::info "Compiling ffmpeg... ($(build::nproc) cores, takes ~10 min)"
  make -j "$(build::nproc)"

  log::info "Installing ffmpeg..."
  $SUDO_CMD make install
  $SUDO_CMD ldconfig
)

build::git_mark_built "ffmpeg"
hash -r 2> /dev/null || true

build::verify_binary "ffmpeg"
build::verify_binary "ffprobe"

build::cleanup "ffmpeg"

# Spot-check codec support
CODECS=$(ffmpeg -codecs 2> /dev/null)
for codec in libx264 libx265 libaom-av1 libvpx-vp9 libopus libmp3lame libfdk_aac; do
  if echo "$CODECS" | grep -q "$codec"; then
    log::info "Codec enabled: ${codec}"
  else
    log::warn "Codec NOT found: ${codec} -- check configure output"
  fi
done

log::info "ffmpeg ${VERSION} done"
