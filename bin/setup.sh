#!/usr/bin/env bash
# bin/setup.sh -- Initialize local environment and secret files.
# This script is non-destructive and will only create files that do not exist.

set -Eeuo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DOTFILES_ROOT

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

setup::init_file() {
  local src="$1"
  local dst="${src%.example}"

  if [[ -f "$dst" ]]; then
    log::info "  (skip) ${dst#"$DOTFILES_ROOT"/} already exists"
  else
    cp "$src" "$dst"
    log::info "  (init) created ${dst#"$DOTFILES_ROOT"/}"
    # If it's a secret file, set strict permissions
    if [[ "$dst" == *"pass"* || "$dst" == *"key"* || "$dst" == *"secret"* ]]; then
      chmod 600 "$dst"
      log::debug "  (perm) set 600 on ${dst#"$DOTFILES_ROOT"/}"
    fi
  fi
}

setup::main() {
  banner::print "setup"
  log::info "Initializing local configuration..."

  local example
  while IFS= read -r example; do
    setup::init_file "$example"
  done < <(find "${DOTFILES_ROOT}/local" -type f -name "*.example")

  echo
  log::warn "IMPORTANT: Local environment and secrets have been initialized."
  log::warn "Please review and edit the following files before running bootstrap:"
  log::warn "  - local/env.sh"
  log::warn "  - local/restic_pass (if using backups)"
  echo
  log::info "Next step: make bootstrap PROFILE=desktop"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  setup::main "$@"
fi
