#!/usr/bin/env bash

set -Eeuo pipefail

source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

XXKB_CONFIG="${HOME}/.xxkbrc"
REAL_CONFIG=$(readlink -f "$XXKB_CONFIG")

if [[ -f "$REAL_CONFIG" ]]; then
  # We use '|' as the delimiter instead of '/' because paths contain slashes.
  # ^ matches start of line, ensuring we don't match comments or partial keys.
  sed -i "s|^XXkb.image.path:.*|XXkb.image.path: ${HOME}/.config/xxkb/flags|" "$REAL_CONFIG"

  log::info "XXKB path updated to: ${HOME}/.config/xxkb/flags"
else
  log::warn "XXKB config not found at $XXKB_CONFIG"
fi
