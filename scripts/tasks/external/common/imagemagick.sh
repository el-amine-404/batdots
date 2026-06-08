#!/usr/bin/env bash
# ImageMagick -- Image manipulation. Built from source for maximum delegate support.
# Depends on: libheif, libavif, libwebp, libjxl, libraw, exiv2, libde265 (all pre-installed).
# Moved from external/debian/ to common/ -- purge logic is now distro-aware.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-imagemagick"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "IMAGEMAGICK")

build::binary_already_installed "magick" "$VERSION" \
  'magick --version | grep -oP "ImageMagick \K[0-9]+\.[0-9]+\.[0-9]+-[0-9]+"' && exit 0

# Purge any system ImageMagick to prevent delegate/library conflicts
build::purge_system_package "imagemagick"
build::purge_system_package "imagemagick-6-common"

# ImageMagick GitHub tags have no 'v' prefix (e.g. "7.1.1-38")
TAG="$VERSION"
URL="https://github.com/ImageMagick/ImageMagick/archive/refs/tags/${TAG}.tar.gz"
src_dir=$(build::fetch_tarball "imagemagick" "$VERSION" "$URL")

build::make_install "$src_dir" \
  --with-modules \
  --enable-shared \
  --with-heic \
  --with-rsvg \
  --with-webp \
  --with-jpeg \
  --with-openjp2 \
  --with-png \
  --with-tiff \
  --with-xml \
  --with-x \
  --with-openexr \
  --with-pango \
  --with-lzma \
  --with-bzlib \
  --with-zlib \
  --with-raw \
  --with-jxl \
  --without-magick-plus-plus

hash -r 2> /dev/null || true

build::verify_binary "magick"

# Show enabled delegates for confirmation
log::info "ImageMagick ${VERSION} installed"
magick --version | grep -i "delegates" | head -1 | while IFS= read -r line; do
  log::info "$line"
done
