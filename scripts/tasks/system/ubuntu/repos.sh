#!/usr/bin/env bash
# scripts/tasks/system/ubuntu/repos.sh
# Enables Universe, Restricted, and Multiverse repositories and installs codecs.
# Compatible with Ubuntu, Linux Mint, Pop!_OS, etc.

set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

if [[ -f /etc/os-release ]]; then
  source /etc/os-release
else
  log::fatal "Cannot detect OS: /etc/os-release missing."
fi

# 1. Verification: Ensure we are on an Ubuntu-like system
# ------------------------------------------------------------------------------
IS_UBUNTU_LIKE=false
if [[ ${ID:-} == "ubuntu" || ${ID_LIKE:-} == *"ubuntu"* ]]; then
  IS_UBUNTU_LIKE=true
fi

if [[ $IS_UBUNTU_LIKE == false ]]; then
  log::warn "This script is for Ubuntu-based systems only. Detected: ${ID:-unknown}"
  exit 0
fi

log::info "Configuring Ubuntu/Mint Repositories (Universe/Restricted/Multiverse)..."

# 2. Prerequisites
# ------------------------------------------------------------------------------
os::check_dependency "curl" "sudo"
if ! command -v add-apt-repository > /dev/null; then
  log::info "Installing software-properties-common..."
  $SUDO_CMD apt-get update -qq
  $SUDO_CMD apt-get install -y software-properties-common
fi

# 3. Enable Components
# ------------------------------------------------------------------------------
# We use -y to automate the prompt and -u to skip the immediate update (we'll do it once at the end)
log::info "Enabling Universe, Restricted, and Multiverse..."
$SUDO_CMD add-apt-repository -y universe
$SUDO_CMD add-apt-repository -y restricted
$SUDO_CMD add-apt-repository -y multiverse

# 4. Automate EULA for Microsoft Fonts
# ------------------------------------------------------------------------------
# This prevents the install from hanging at a purple TUI screen
log::info "Pre-accepting MS Core Fonts EULA..."
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | $SUDO_CMD debconf-set-selections

# 5. Install Codecs
# ------------------------------------------------------------------------------
log::info "Installing multimedia codecs..."
$SUDO_CMD apt-get update -qq

if [[ ${ID:-} == "linuxmint" ]]; then
  # Mint's dedicated codec pack
  $SUDO_CMD apt-get install -y mint-meta-codecs
else
  # Standard Ubuntu codec pack
  $SUDO_CMD apt-get install -y ubuntu-restricted-extras
fi

log::info "Ubuntu/Mint repositories and codecs configured successfully."
