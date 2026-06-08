#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: VIRTUALBOX (Open Source Edition Only)
# Installs Latest Oracle VirtualBox.
# SECURITY NOTE: Skips Proprietary Extension Pack (No USB 3.0/RDP).
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# 1. OS Compatibility Check
# ------------------------------------------------------------------------------
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  # Mint uses 'wilma', but VirtualBox needs the Ubuntu base ('noble'/'jammy')
  TARGET_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

  if [[ -z $TARGET_CODENAME ]]; then
    log::error "Could not determine OS Codename for VirtualBox Repository."
    exit 1
  fi
else
  log::error "OS release file not found. Cannot configure repository."
  exit 1
fi

log::debug "Detected Target Codename: $TARGET_CODENAME"

# 2. Add Repository & Key (Idempotent)
# ------------------------------------------------------------------------------
log::info "Configuring Oracle VirtualBox Repository..."

installer::apt::add_key \
  "oracle-virtualbox" \
  "https://www.virtualbox.org/download/oracle_vbox_2016.asc"

REPO_STRING="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/oracle-virtualbox.gpg] https://download.virtualbox.org/virtualbox/debian $TARGET_CODENAME contrib"
installer::apt::add_repo "virtualbox" "$REPO_STRING"

# 3. Dynamic Version Detection & Install
# ------------------------------------------------------------------------------
log::info "Checking for latest VirtualBox version..."

# Update cache to see new versions
$SUDO_CMD apt-get update -qq

# Find the package name with the highest version number (e.g., virtualbox-7.1)
LATEST_PKG=$(apt-cache search virtualbox | grep -P "^virtualbox-\d+\.\d+" | sort -V | tail -n 1 | awk '{print $1}')

if [[ -z $LATEST_PKG ]]; then
  log::error "Could not find any 'virtualbox-x.x' package in the repository."
  exit 1
fi

log::info "Latest available package: $LATEST_PKG"
installer::apt::install "$LATEST_PKG" dkms build-essential linux-headers-"$(uname -r)"

# 4. User Group Configuration
# ------------------------------------------------------------------------------
# Still required for basic USB 1.1 passthrough and bridging
if ! groups "$USER" | grep -q "vboxusers"; then
  log::info "Adding user '$USER' to 'vboxusers' group..."
  $SUDO_CMD usermod -aG vboxusers "$USER"
  log::warn "You must LOG OUT and LOG BACK IN for VirtualBox permissions to take effect."
else
  log::info "User '$USER' is already in 'vboxusers' group."
fi

log::info "VirtualBox setup complete"
