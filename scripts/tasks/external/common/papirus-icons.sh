#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: PAPIRUS ICON THEME
# Installs/Updates Papirus icons to ~/.local/share/icons.
# UPDATE STRATEGY: Checks GitHub Release Tag vs Local .version file.
# TRUST LEVEL: Executes official install.sh from maintainer.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

# 1. Configuration
# ------------------------------------------------------------------------------
DEST_DIR="${HOME}/.local/share/icons"
THEME_NAME="Papirus"
VERSION_FILE="${DEST_DIR}/${THEME_NAME}/.version"
INSTALLER_URL="https://raw.githubusercontent.com/${PAPIRUS_ICONS_REPO}/master/install.sh"

# 2. Fetch Latest Version
# ------------------------------------------------------------------------------
LATEST_TAG=$(build::resolve_version "PAPIRUS_ICONS")

# 3. Check Installed Version
# ------------------------------------------------------------------------------
CURRENT_VERSION="none"
if [[ -f $VERSION_FILE ]]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
fi

if [[ $CURRENT_VERSION == "$LATEST_TAG" ]]; then
  log::info "Papirus Icon Theme is up to date ($CURRENT_VERSION)."
  exit 0
fi

log::info "Update Available: ${CURRENT_VERSION} -> ${LATEST_TAG}"

# 4. Install / Update
# ------------------------------------------------------------------------------
log::info "Installing..."

# Ensure destination exists
mkdir -p "$DEST_DIR"

# Download the installer script safely using our library
TEMP_SCRIPT=$(mktemp)
http::download "$INSTALLER_URL" "$TEMP_SCRIPT"

# Run the installer
# We pass DESTDIR env var to tell the script where to install.
# The official script handles removing old files automatically.
if DESTDIR="$DEST_DIR" sh "$TEMP_SCRIPT"; then
  log::info "Papirus installed successfully."

  # 5. Stamp the Version
  # We update the version file only on success
  echo "$LATEST_TAG" > "$VERSION_FILE"
else
  log::error "Installation failed."
  rm -f "$TEMP_SCRIPT"
  exit 1
fi

rm -f "$TEMP_SCRIPT"
