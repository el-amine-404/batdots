#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: STARSHIP PROMPT
# Installs or Updates Starship (The Cross-Shell Prompt).
# ==============================================================================

source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"

# 1. Configuration
# ------------------------------------------------------------------------------
BIN_DIR="${HOME}/.local/bin"

# 2. Dependency Check
# ------------------------------------------------------------------------------
os::check_dependency curl jq || exit 1

# 3. Check Local Version
# ------------------------------------------------------------------------------
CURRENT_VERSION="none"

if command -v starship > /dev/null; then
  # Output format: "starship 1.16.0" -> extracts "1.16.0"
  CURRENT_VERSION=$(starship --version | head -n 1 | cut -d ' ' -f 2)
fi

# 4. Check Remote Version
# ------------------------------------------------------------------------------
LATEST_VERSION=$(build::resolve_version "STARSHIP")

# 5. Compare & Decision
# ------------------------------------------------------------------------------
if [[ $CURRENT_VERSION == "$LATEST_VERSION" ]]; then
  log::debug "Starship is up to date ($CURRENT_VERSION)."
  exit 0
fi

log::info "Update Available: ${CURRENT_VERSION} -> ${LATEST_VERSION}"

# 6. Install / Update
# ------------------------------------------------------------------------------
log::info "Installing Starship..."
# -y: Auto-confirm, -b: User Bin Directory
if curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR" > /dev/null; then
  log::info "Starship updated to ${LATEST_VERSION}."
else
  log::error "Starship installation failed."
  exit 1
fi
