#!/usr/bin/env bash
# scripts/user/archive-flutter.sh -- Archive Flutter project(s) excluding caches.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

af::archive_one() {
  archive::project project::is_flutter "$1"
}

af::main() {
  banner::print "archive flutter"
  project::parse_args "$@" || exit 1
  if ((PROJECT_OPT_RECURSIVE)); then
    project::for_each_matching project::is_flutter \
      "$PROJECT_OPT_TARGET" af::archive_one
  else
    af::archive_one "$PROJECT_OPT_TARGET"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  af::main "$@"
fi
