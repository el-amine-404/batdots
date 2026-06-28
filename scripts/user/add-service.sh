#!/usr/bin/env bash
# scripts/user/add-service.sh -- Scaffold a new docker service directory.
#
# Usage:
#   add-service.sh <service_name>
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

main() {
  banner::print "add service"

  if [[ $# -ne 1 ]]; then
    log::fatal "Usage: $(basename "$0") <name_of_service>"
  fi

  local service_name="$1"

  if [[ -d $service_name ]]; then
    log::fatal "Directory '$service_name' already exists."
  fi

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "[DRY RUN] Would create directory '${service_name}/data' and scaffold files."
    return 0
  fi

  log::info "Creating directory ${service_name}/data..."
  dir::create "${service_name}/data"

  log::info "Scaffolding config files..."
  touch "${service_name}/docker-compose.yml"
  touch "${service_name}/.env"
  touch "${service_name}/README.md"

  log::info "Service '$service_name' successfully scaffolded."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
