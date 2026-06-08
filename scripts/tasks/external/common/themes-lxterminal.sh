#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=../../lib/bash-utilities.sh
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/lib/themes.sh"

# Ensure the destination exists before the library tries to use it
mkdir -p "${HOME}/.config/lxterminal/themes"

# Use the library to handle syncing and linking
themes::install_from_list "lxterminal"

log::info "LXTerminal themes setup complete."
