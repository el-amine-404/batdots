#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

NANO_CONFIG_DIR="${HOME}/.config/nano"
SYNTAX_DIR="${NANO_CONFIG_DIR}/syntax"
NANO_SYNTAX_REPO=$(source::resolve_repo_url "NANO_SYNTAX")

# 1. Pre-flight
os::check_dependency "nano" "git"

github::sync_repo \
  "$NANO_SYNTAX_REPO" \
  "$SYNTAX_DIR" \
  1 \
  "master"

log::info "Nano setup successfully healed and updated."
