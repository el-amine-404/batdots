#!/usr/bin/env bash
# scripts/user/archive-ionic.sh -- Archive Ionic project(s) excluding caches.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

ai::archive_one() {
  archive::project project::is_ionic "$1"
}

ai::main() {
  banner::print "archive ionic"
  project::parse_args "$@" || exit 1
  if ((PROJECT_OPT_RECURSIVE)); then
    project::for_each_matching project::is_ionic \
      "$PROJECT_OPT_TARGET" ai::archive_one
  else
    ai::archive_one "$PROJECT_OPT_TARGET"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ai::main "$@"
fi
