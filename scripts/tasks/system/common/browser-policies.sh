#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# ==============================================================================
# SYSTEM TASK: BROWSER POLICIES
# Installs managed policies to /etc/ for system-wide configuration.
# ==============================================================================

log::info "Configuring System Browser Policies..."

# 1. Chromium Based Browsers (Chrome, Brave, Chromium)
# ------------------------------------------------------------------------------
SRC_CHROMIUM="${DOTFILES_ROOT}/apps/chromium/policies.json"

if [[ -f $SRC_CHROMIUM ]]; then
  # List of target directories for different browsers
  TARGETS=(
    "/etc/chromium/policies/managed/policies.json"
    "/etc/opt/chrome/policies/managed/policies.json"
    "/etc/brave/policies/managed/policies.json"
  )

  for target in "${TARGETS[@]}"; do
    target_dir=$(dirname "$target")

    # Only update if changed
    if ! cmp -s "$SRC_CHROMIUM" "$target"; then
      log::info "Updating Policy: $target"

      $SUDO_CMD mkdir -p -m 0755 "$target_dir"
      $SUDO_CMD rm -f "$target"
      $SUDO_CMD cp "$SRC_CHROMIUM" "$target"

      # Enforce System Permissions
      $SUDO_CMD chown root:root "$target"
      $SUDO_CMD chmod 644 "$target"
    fi
  done
else
  log::warn "Source missing: $SRC_CHROMIUM"
fi

# 2. Firefox
# ------------------------------------------------------------------------------
SRC_FIREFOX="${DOTFILES_ROOT}/apps/firefox/policies.json"
TARGET_FIREFOX="/etc/firefox/policies/policies.json"

if [[ -f $SRC_FIREFOX ]]; then
  if ! cmp -s "$SRC_FIREFOX" "$TARGET_FIREFOX"; then
    log::info "Updating Firefox Policy..."

    $SUDO_CMD mkdir -p -m 0755 "$(dirname "$TARGET_FIREFOX")"
    $SUDO_CMD rm -f "$TARGET_FIREFOX"
    $SUDO_CMD cp "$SRC_FIREFOX" "$TARGET_FIREFOX"

    # Enforce System Permissions
    $SUDO_CMD chown root:root "$TARGET_FIREFOX"
    $SUDO_CMD chmod 644 "$TARGET_FIREFOX"
  fi
else
  log::warn "Source missing: $SRC_FIREFOX"
fi
