#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: JETBRAINS TOOLBOX
# Installs/Updates JetBrains Toolbox.
# Strategy: Official Tarball Install + Legacy Root Cleanup.
# ==============================================================================

source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"

# 1. Configuration
INSTALL_DIR="${HOME}/.local/share/jetbrains-toolbox"
BIN_LINK="${HOME}/.local/bin/jetbrains-toolbox"
API_URL=$(source::resolve_repo_url "TOOLBOX")

# 2. Architecture Detection
ARCH=$(os::get_architecture)
case "$ARCH" in
  x86_64) JB_PLATFORM="linux" ;;
  aarch64) JB_PLATFORM="linuxARM64" ;;
  *)
    log::error "Architecture $ARCH not supported."
    exit 1
    ;;
esac

# 3. Fetch Update Info
log::info "Checking JetBrains Toolbox updates..."
if ! JSON_DATA=$(http::api_get "$API_URL"); then
  log::error "Failed to fetch JetBrains Toolbox updates."
  exit 1
fi

LATEST_BUILD=$(echo "$JSON_DATA" | jq -r '.TBA[0].build')
DOWNLOAD_URL=$(echo "$JSON_DATA" | jq -r ".TBA[0].downloads.${JB_PLATFORM}.link")

if [[ $LATEST_BUILD == "null" || $DOWNLOAD_URL == "null" ]]; then
  log::error "Failed to parse API data."
  exit 1
fi

# 4. Version Check
CURRENT_BUILD="none"
VERSION_FILE="${INSTALL_DIR}/.version"
[[ -f $VERSION_FILE ]] && CURRENT_BUILD=$(cat "$VERSION_FILE")

if [[ $CURRENT_BUILD == "$LATEST_BUILD" ]]; then
  log::debug "JetBrains Toolbox is up to date ($CURRENT_BUILD)."
  # We still allow the script to continue to the Cleanup section below
  # just in case a legacy install exists even if the new one is up to date.
else
  log::info "Update Available: ${CURRENT_BUILD} -> ${LATEST_BUILD}"

  # 5. Atomic Install
  TEMP_DIR=$(mktemp -d)
  TEMP_FILE="${TEMP_DIR}/toolbox.tar.gz"

  if ! http::download "$DOWNLOAD_URL" "$TEMP_FILE"; then
    log::error "Failed to download JetBrains Toolbox."
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  log::info "Extracting..."
  tar -xzf "$TEMP_FILE" -C "$TEMP_DIR"

  # Find extracted folder (e.g., jetbrains-toolbox-3.2.0.x)
  EXTRACTED_FOLDER=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "jetbrains-toolbox-*" | head -n 1)

  if [[ -z $EXTRACTED_FOLDER ]]; then
    log::error "Failed to find extracted directory."
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  # Locate binary (Root or /bin)
  APP_BINARY=""
  if [[ -f "$EXTRACTED_FOLDER/jetbrains-toolbox" ]]; then
    APP_BINARY="$EXTRACTED_FOLDER/jetbrains-toolbox"
  elif [[ -f "$EXTRACTED_FOLDER/bin/jetbrains-toolbox" ]]; then
    APP_BINARY="$EXTRACTED_FOLDER/bin/jetbrains-toolbox"
  fi

  if [[ -z $APP_BINARY ]]; then
    log::error "Binary not found in extracted folder."
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  log::info "Installing to User Space..."

  if [[ -d $INSTALL_DIR ]]; then rm -rf "$INSTALL_DIR"; fi
  mv "$EXTRACTED_FOLDER" "$INSTALL_DIR"

  echo "$LATEST_BUILD" > "${INSTALL_DIR}/.version"

  # Link the binary
  RELATIVE_BIN_PATH="${APP_BINARY#$EXTRACTED_FOLDER/}"
  FINAL_BIN_PATH="${INSTALL_DIR}/${RELATIVE_BIN_PATH}"

  chmod +x "$FINAL_BIN_PATH"
  ln -sf "$FINAL_BIN_PATH" "$BIN_LINK"

  rm -rf "$TEMP_DIR"
  log::info "JetBrains Toolbox updated to ${LATEST_BUILD}."
fi

# 6. Legacy Cleanup (User Space)
# ------------------------------------------------------------------------------
LEGACY_USER_DIR="${HOME}/.local/share/JetBrains/Toolbox"
if [[ -d $LEGACY_USER_DIR ]]; then
  log::warn "Removing legacy User-Space installation ($LEGACY_USER_DIR)..."
  rm -rf "$LEGACY_USER_DIR"
fi

# 7. Legacy Cleanup (Root Space /opt) - The "Ghost Buster"
# ------------------------------------------------------------------------------
# We use compgen to check for wildcards because [ -d /opt/jetbrains* ] doesn't work directly
if compgen -G "/opt/jetbrains-toolbox*" > /dev/null; then
  log::warn "Detected legacy Root installation in /opt. Removing..."

  # Use SUDO_CMD from bootstrap if available, else standard sudo
  EXEC_SUDO="${SUDO_CMD:-sudo}"

  # Run removal
  if $EXEC_SUDO rm -rf /opt/jetbrains-toolbox*; then
    log::info "Legacy /opt installation removed successfully."
  else
    log::error "Failed to remove /opt files. You may need to run 'sudo rm -rf /opt/jetbrains-toolbox*' manually."
  fi
fi
