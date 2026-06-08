#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: FIREFOX (Debian/Mint/Ubuntu)
# Installs Firefox from the official Mozilla APT repository.
# Sets Pin-Priority to override system packages.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

log::info "Configuring Mozilla Official Repository..."

# 1. Add Signing Key
installer::apt::add_key "packages.mozilla.org" "$FIREFOX_DEBIAN_KEY_URL"

# 2. Add Repository
ARCH=$(dpkg --print-architecture)
REPO_STRING="deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.mozilla.org.gpg] ${FIREFOX_DEBIAN_REPO_URL} ${FIREFOX_DEBIAN_VERSION} main"
installer::apt::add_repo "mozilla" "$REPO_STRING"

# 3. Set Pin Priority (Crucial)
# This guarantees apt picks this repo over the default Mint/Debian repo
PREF_FILE="/etc/apt/preferences.d/mozilla"
if [[ ! -f $PREF_FILE ]]; then
  log::info "Setting APT Pin Priority for Mozilla..."
  echo 'Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000' | $SUDO_CMD tee "$PREF_FILE" > /dev/null
fi

# 4. Install
log::info "Installing Firefox..."
installer::apt::install firefox
