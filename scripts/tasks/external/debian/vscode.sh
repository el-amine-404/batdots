#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: VS CODE (Microsoft Repo)
# Installs VS Code, Extensions, and links config files.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

# PATHS
VSCODE_CONFIG_DIR="${DOTFILES_ROOT}/apps/vscode"
EXT_FILE="${VSCODE_CONFIG_DIR}/extensions.txt"

# 1. Install VS Code (Application)
# ------------------------------------------------------------------------------
log::info "Configuring Microsoft VS Code Repository..."

installer::apt::add_key "packages.microsoft" "$VSCODE_KEY_URL"

ARCH=$(dpkg --print-architecture)
REPO_STRING="deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] ${VSCODE_REPO_URL} ${VSCODE_VERSION} main"
installer::apt::add_repo "vscode" "$REPO_STRING"

log::info "Installing VS Code..."
installer::apt::install code apt-transport-https

# 2. Install Extensions (Idempotent)
# ------------------------------------------------------------------------------
if [[ ! -f $EXT_FILE ]]; then
  log::warn "Extension list not found at $EXT_FILE. Skipping extensions."
  exit 0
fi

log::info "Installing VS Code Extensions..."

# Get installed extensions once (Optimization)
INSTALLED_EXTS=$(code --list-extensions)

while IFS= read -r ext || [[ -n $ext ]]; do
  # Skip comments and empty lines
  [[ $ext =~ ^#.*$ ]] || [[ -z $ext ]] && continue

  # Check against installed list
  if echo "$INSTALLED_EXTS" | grep -qi "^${ext}$"; then
    log::debug "Skipping $ext (Already installed)"
  else
    log::info "Installing $ext..."
    # We capture output to keep logs clean, only show errors
    if ! code --install-extension "$ext" --force &> /dev/null; then
      log::warn "Failed to install $ext"
    fi
  fi
done < "$EXT_FILE"

log::info "VS Code setup complete."
