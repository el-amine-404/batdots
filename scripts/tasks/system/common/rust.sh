#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# SYSTEM TASK: RUST TOOLCHAIN
# Installs/Updates the official Rust compiler and Cargo package manager.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

export RUSTUP_HOME="${HOME}/.rustup"
export CARGO_HOME="${HOME}/.cargo"
CARGO_ENV="${CARGO_HOME}/env"

os::check_dependency "curl"

# Try sourcing env in case it's installed but not in PATH
if [[ -f $CARGO_ENV ]]; then
  # shellcheck source=/dev/null
  source "$CARGO_ENV"
fi

if command -v rustup > /dev/null 2>&1; then
  log::info "Rust is already installed. Checking for updates..."
  if rustup update stable; then
    log::info "Rust toolchain updated successfully."
  else
    log::fatal "Failed to update Rust toolchain."
  fi
else
  # -sSf: Silent, Show error, Fail on error
  # -y: Disable confirmation prompts
  if curl --proto '=https' --tlsv1.2 -sSf "$RUSTUP_URL" | sh -s -- -y; then
    log::info "Rust installer completed."

    # Load the new environment immediately
    if [[ -f $CARGO_ENV ]]; then
      # shellcheck source=/dev/null
      source "$CARGO_ENV"
    else
      log::fatal "Installer finished, but environment file not found at: $CARGO_ENV"
    fi
  else
    log::fatal "Rust installation script failed."
  fi
fi

# Verify
if command -v cargo &> /dev/null; then
  VERSION=$(cargo --version)
  log::debug "Cargo available: $VERSION"
else
  log::error "Rust installation appeared to succeed, but 'cargo' is not found."
  exit 1
fi
