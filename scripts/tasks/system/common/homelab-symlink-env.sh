#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

CONFIGS_ROOT="${DOTFILES_HOMELAB_CONFIGS_ROOT:?DOTFILES_HOMELAB_CONFIGS_ROOT must be set in local/env.sh}"
GLOBAL_ENV="${CONFIGS_ROOT}/.env"

hlsymlink::run() {
  log::info "Checking for global .env file at ${GLOBAL_ENV}..."

  if [[ ! -f $GLOBAL_ENV ]]; then
    log::warn "Global .env file not found at '${GLOBAL_ENV}'. Skipping symlinking."
    return 0
  fi

  log::info "Linking global .env to all service directories in ${CONFIGS_ROOT}..."

  local dir
  for dir in "${CONFIGS_ROOT}"/*; do
    [[ -d $dir ]] || continue
    [[ $(basename "$dir") == .* ]] && continue

    local target="${dir}/.env"

    # Check if a real file exists and is not a symlink
    if [[ -f $target && ! -L $target ]]; then
      log::warn "Skipping: a real .env file already exists at ${target}"
      continue
    fi

    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
      log::info "  [DRY RUN] Would link ${target} -> ../.env"
    else
      $SUDO_CMD ln -snf "../.env" "$target"
      log::info "  Linked ${target}"
    fi
  done
}

main() {
  banner::print "homelab symlink env"
  hlsymlink::run
}

main "$@"
