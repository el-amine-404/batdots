#!/usr/bin/env bash
# scripts/user/caddy-fmt.sh -- Format the Caddyfile in the running Docker container.
#
# Usage:
#   caddy-fmt.sh
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

main() {
  banner::print "caddy format"
  os::check_dependency docker || exit 1

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "[DRY RUN] Would execute: docker compose exec -w /etc/caddy caddy caddy fmt --overwrite"
    return 0
  fi

  log::info "Formatting Caddyfile..."
  docker compose exec -w /etc/caddy caddy caddy fmt --overwrite
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
