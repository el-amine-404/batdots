#!/usr/bin/env bash
# scripts/tasks/system/common/brightness.sh
# Grants the current user permissions to use brightnessctl without sudo.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

banner::print "brightness-setup"

# brightnessctl requires membership in 'video' (or sometimes 'input') group.
# Note: On some modern systems, 'video' is enough.
for group in "video" "input"; do
  if ! groups "$USER" | grep -q "\b${group}\b"; then
    log::info "Adding user to '${group}' group..."
    $SUDO_CMD usermod -aG "$group" "$USER"
    log::warn "  You may need to log out and back in for '${group}' group changes to take effect."
  else
    log::debug "User already in '${group}' group."
  fi
done

log::info "Brightness setup complete."
