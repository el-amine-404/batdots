#!/usr/bin/env bash
# libvmaf -- Perceptual video quality assessment.
# Note: meson root is in libvmaf/ subdirectory.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-libvmaf"
build::ensure_pkg_config_path

VERSION=$(build::resolve_version "LIBVMAF")
build::already_installed "libvmaf" "$VERSION" && exit 0

src_dir=$(build::fetch_git "vmaf" "https://github.com/Netflix/vmaf.git" "v${VERSION}")

build::meson_install "${src_dir}/libvmaf" \
  -Denable_tests=false \
  -Denable_docs=false

build::verify_pkgconfig "libvmaf"
build::cleanup "vmaf"
log::info "libvmaf ${VERSION} done"
