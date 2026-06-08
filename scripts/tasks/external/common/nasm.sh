#!/usr/bin/env bash
# NASM -- Netwide Assembler. Required for optimized x264/ffmpeg builds.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-nasm"

VERSION=$(build::resolve_version "NASM")
build::binary_already_installed "nasm" "$VERSION" 'nasm -v | grep -oP "version \K[^ ]+"' && exit 0

URL="https://www.nasm.us/pub/nasm/releasebuilds/${VERSION}/nasm-${VERSION}.tar.gz"
src_dir=$(build::fetch_tarball "nasm" "$VERSION" "$URL")

build::make_install "$src_dir"

build::verify_binary "nasm"
build::cleanup "nasm"
log::info "nasm ${VERSION} done"
