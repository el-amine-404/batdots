#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: 7-ZIP (Official Binary)
# Installs the modern official 7-Zip (7zz) from GitHub.
# Auto-detects Architecture (x64 vs arm64).
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

# 1. Dependency Check
# ------------------------------------------------------------------------------
os::check_dependency curl tar xz || exit 1

# 2. Auto-Detect Architecture
# ------------------------------------------------------------------------------
RAW_ARCH=$(os::get_architecture)
ARCH=""

case "$RAW_ARCH" in
  x86_64) ARCH="linux-x64" ;;
  aarch64) ARCH="linux-arm64" ;; # For modern ARM (Raspberry Pi 4/5, VMs)
  armv7l) ARCH="linux-arm" ;;    # For older ARM (Raspberry Pi 3)
  *)
    log::error "Unsupported System Architecture: $RAW_ARCH"
    exit 1
    ;;
esac

log::debug "Detected Architecture: $RAW_ARCH -> $ARCH"

# 3. Resolve Version
# ------------------------------------------------------------------------------
LATEST_TAG=$(build::resolve_version "S7ZIP")

# 4. Setup Variables
# ------------------------------------------------------------------------------
VERSION_CLEAN="${LATEST_TAG//./}"
DOWNLOAD_URL="https://github.com/${S7ZIP_REPO}/releases/download/${LATEST_TAG}/7z${VERSION_CLEAN}-${ARCH}.tar.xz"
INSTALL_DIR="/opt/7-zip-${VERSION_CLEAN}"

# 5. Check Installed Version & Path
# ------------------------------------------------------------------------------
CURRENT_VERSION=""
EXISTING_BIN=""

if command -v 7zz &> /dev/null; then
  EXISTING_BIN=$(command -v 7zz)
  # Parse version
  CURRENT_VERSION=$(7zz -version 2> /dev/null | head -n 2 | grep -Po '(\d+\.\d+)' | head -1) || true
fi

# 6. Update Decision
# ------------------------------------------------------------------------------
if [[ $CURRENT_VERSION == "$LATEST_TAG" ]]; then
  log::info "7-Zip is already up to date ($CURRENT_VERSION)."
  exit 0
elif [[ -n $CURRENT_VERSION ]]; then
  log::info "Update Available: $CURRENT_VERSION -> $LATEST_TAG"
else
  log::info "Installing 7-Zip $LATEST_TAG ($ARCH)..."
fi

# 7. Smart Cleanup (Targeted Removal)
# ------------------------------------------------------------------------------
if [[ -n $EXISTING_BIN ]]; then
  # Resolve the absolute path of the binary (e.g., /opt/7-zip-2301/7zz)
  REAL_PATH=$(readlink -f "$EXISTING_BIN")
  OLD_INSTALL_DIR=$(dirname "$REAL_PATH")

  # Safety: Only delete if it lives in /opt/7-zip*
  if [[ $OLD_INSTALL_DIR == "/opt/7-zip"* ]]; then
    log::info "Removing old installation at: $OLD_INSTALL_DIR"
    $SUDO_CMD rm -rf "$OLD_INSTALL_DIR"
  fi
fi

# 8. Install New Version
# ------------------------------------------------------------------------------
log::info "Installing..."
$SUDO_CMD mkdir -p "$INSTALL_DIR"

TEMP_FILE=$(mktemp)
if http::download "$DOWNLOAD_URL" "$TEMP_FILE"; then
  # Extract
  $SUDO_CMD tar -xJf "$TEMP_FILE" -C "$INSTALL_DIR"
  rm -f "$TEMP_FILE"

  # Symlink
  log::info "Linking binary..."
  $SUDO_CMD rm -f /usr/local/bin/7zz
  $SUDO_CMD ln -sf "${INSTALL_DIR}/7zz" /usr/local/bin/7zz

  # Permissions
  $SUDO_CMD chmod +x "${INSTALL_DIR}/7zz"

  log::info "7-Zip ($LATEST_TAG) installed successfully!"
else
  log::error "Download failed from $DOWNLOAD_URL"
  rm -f "$TEMP_FILE"
  exit 1
fi
