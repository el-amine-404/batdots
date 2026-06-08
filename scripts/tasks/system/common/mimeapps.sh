#!/usr/bin/env bash
set -Eeuo pipefail

source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

LOCAL_APPS="$HOME/.local/share/applications"

# 1. Ensure dependencies exist (nsxiv, zathura, and mpv should be in your packages list)
os::check_dependency "update-desktop-database"

# 3. Update the database so Linux indexes our new launchers
update-desktop-database "$LOCAL_APPS"

log::info "MIME Security Setup Complete."
