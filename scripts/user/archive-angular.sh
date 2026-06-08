#!/usr/bin/env bash
# scripts/user/archive-angular.sh -- Archive Angular project(s) excluding caches.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

aa::archive_one() {
  archive::project project::is_angular "$1"
}

aa::main() {
  banner::print "archive angular"
  project::parse_args "$@" || exit 1
  if ((PROJECT_OPT_RECURSIVE)); then
    project::for_each_matching project::is_angular \
      "$PROJECT_OPT_TARGET" aa::archive_one
  else
    aa::archive_one "$PROJECT_OPT_TARGET"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  aa::main "$@"
fi
