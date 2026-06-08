#!/usr/bin/env bash
# scripts/user/archive-auto.sh -- Sniff project type and dispatch.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

az::dispatch_one() {
  local dir="$1"
  local type
  if ! type=$(project::auto_detect "$dir"); then
    log::warn "no recognized project type: $dir"
    return 0
  fi
  local script="${AZ_SCRIPT_DIR}/archive-${type}.sh"
  if [[ ! -x $script ]]; then
    log::error "missing dispatch script: $script"
    return 1
  fi
  log::info "detected '${type}' -> ${script##*/} for: $dir"
  "$script" "$dir"
}

az::main() {
  banner::print "archive auto"
  project::parse_args "$@" || exit 1
  AZ_SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")

  if ((PROJECT_OPT_RECURSIVE)); then
    project::for_each_matching project::is_any_recognized \
      "$PROJECT_OPT_TARGET" az::dispatch_one
  else
    az::dispatch_one "$PROJECT_OPT_TARGET"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  az::main "$@"
fi
