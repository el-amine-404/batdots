#!/usr/bin/env bash
# scripts/user/archive-java.sh -- Archive Java project(s) excluding caches.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

aj::archive_one() {
  archive::project project::is_java "$1"
}

aj::main() {
  banner::print "archive java"
  project::parse_args "$@" || exit 1
  if ((PROJECT_OPT_RECURSIVE)); then
    project::for_each_matching project::is_java \
      "$PROJECT_OPT_TARGET" aj::archive_one
  else
    aj::archive_one "$PROJECT_OPT_TARGET"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  aj::main "$@"
fi
