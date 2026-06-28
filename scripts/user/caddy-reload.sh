#!/usr/bin/env bash
# scripts/user/caddy-reload.sh -- Reload the Caddy configuration in the running Docker container.
#
# Usage:
#   caddy-reload.sh
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

main() {
  banner::print "caddy reload"
  os::check_dependency docker || exit 1

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "[DRY RUN] Would execute: docker compose exec -w /etc/caddy caddy caddy reload --adapter caddyfile --config /etc/caddy/Caddyfile"
    return 0
  fi

  log::info "Reloading Caddy configuration..."
  docker compose exec -w /etc/caddy caddy caddy reload --adapter caddyfile --config /etc/caddy/Caddyfile
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
