#!/usr/bin/env bash
# fonts -- Data-driven font installer for custom/external fonts.
# Uses FONT_COMPONENTS from config/versions.conf.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

banner::print "setup-fonts"

log::info "Installing external fonts from registry..."

for font_prefix in "${FONT_COMPONENTS[@]}"; do
  fonts::install_from_registry "$font_prefix"
done

fonts::refresh_cache
log::info "External fonts installation complete."
