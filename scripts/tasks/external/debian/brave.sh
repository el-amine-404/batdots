#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: BRAVE BROWSER (Debian/Mint/Ubuntu)
# Installs Brave Browser Stable.
# Note: Conflict cleanup is now handled automatically by the installer library.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

log::info "Configuring Brave Browser Repository..."

# 1. Add Signing Key
installer::apt::add_key "brave-browser" "$BRAVE_KEY_URL"

# 2. Add Repository
ARCH=$(dpkg --print-architecture)
REPO_STRING="deb [arch=${ARCH} signed-by=/etc/apt/keyrings/brave-browser.gpg] ${BRAVE_REPO_URL} ${BRAVE_VERSION} main"

installer::apt::add_repo "brave-browser" "$REPO_STRING"

# 3. Install
log::info "Installing Brave Browser..."
installer::apt::install brave-browser
