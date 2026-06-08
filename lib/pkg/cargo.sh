#!/usr/bin/env bash
# Wrapper for Rust Cargo

# 1. Ensure Cargo is in PATH (in case it was just installed)
export CARGO_HOME="${HOME}/.cargo"
if [[ -f "${CARGO_HOME}/env" ]]; then
  source "${CARGO_HOME}/env"
fi

pkg_update() {
  # Rustup handles the toolchain update
  log::info "Updating Rust Toolchain..."
  rustup update stable
}

pkg_install() {
  # Cargo doesn't have a "install list" flag, so we iterate
  # We use --locked for reproducibility
  for crate in "$@"; do
    if cargo install --list | grep -q "^$crate "; then
      log::info "Cargo crate already installed: $crate"
    else
      log::info "Installing Cargo crate: $crate"
      cargo install --locked "$crate"
    fi
  done
}

pkg_clean() {
  # Clean the registry cache to save space
  rm -rf "${CARGO_HOME}/registry/cache"
}
