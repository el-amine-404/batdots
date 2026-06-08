#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: GOOGLE CHROME (Debian/Mint/Ubuntu)
# Installs Google Chrome Stable from official Google repos.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

log::info "Configuring Google Chrome Repository..."

# 1. Add Signing Key
installer::apt::add_key "google-chrome" "$CHROME_KEY_URL"

# 2. Add Repository
ARCH=$(dpkg --print-architecture)
REPO_STRING="deb [arch=${ARCH} signed-by=/etc/apt/keyrings/google-chrome.gpg] ${CHROME_REPO_URL} ${CHROME_VERSION} main"
installer::apt::add_repo "google-chrome" "$REPO_STRING"

# 3. Install
log::info "Installing Google Chrome Stable..."
installer::apt::install google-chrome-stable
