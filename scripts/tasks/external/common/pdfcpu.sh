#!/usr/bin/env bash
# pdfcpu -- independent (Go) PDF processor/validator used by pdf-sanitize as a
# second-parser integrity gate. Installs the official prebuilt binary from the
# pinned GitHub release; architecture is auto-detected.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

main() {
  banner::print "pdfcpu"
  os::check_dependency curl tar xz || exit 1

  local version asset_arch raw_arch url install_dir
  version=$(build::resolve_version "PDFCPU")

  build::binary_already_installed "pdfcpu" "$version" \
    "pdfcpu version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'" && exit 0

  raw_arch=$(os::get_architecture)
  case "$raw_arch" in
    x86_64) asset_arch="Linux_x86_64" ;;
    aarch64) asset_arch="Linux_arm64" ;;
    *)
      log::error "pdfcpu: unsupported architecture: $raw_arch"
      exit 1
      ;;
  esac

  url="https://github.com/${PDFCPU_REPO}/releases/download/${PDFCPU_TAG_PREFIX}${version}/pdfcpu_${version}_${asset_arch}.tar.xz"
  install_dir="/opt/pdfcpu-${version}"

  log::info "Installing pdfcpu ${version} (${asset_arch})..."
  $SUDO_CMD rm -rf "$install_dir"
  $SUDO_CMD mkdir -p "$install_dir"

  local tmp
  tmp=$(mktemp)
  if http::download "$url" "$tmp"; then
    $SUDO_CMD tar -xJf "$tmp" -C "$install_dir"
    rm -f "$tmp"
  else
    log::error "pdfcpu: download failed from $url"
    rm -f "$tmp"
    exit 1
  fi

  # The tarball contains the 'pdfcpu' binary at its top level.
  local bin
  bin=$(find "$install_dir" -maxdepth 2 -type f -name pdfcpu -print -quit)
  [[ -n $bin ]] || {
    log::error "pdfcpu: binary not found in extracted archive"
    exit 1
  }
  $SUDO_CMD chmod +x "$bin"
  $SUDO_CMD ln -sf "$bin" /usr/local/bin/pdfcpu

  build::verify_binary "pdfcpu"
  log::info "pdfcpu ${version} done"
}

main "$@"
