#!/usr/bin/env bash
# scripts/user/archive-latex.sh -- Archive LaTeX project(s) excluding aux files.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

al::archive_one() {
  archive::project project::is_latex "$1"
}

al::main() {
  banner::print "archive latex"
  project::parse_args "$@" || exit 1
  if ((PROJECT_OPT_RECURSIVE)); then
    project::for_each_matching project::is_latex \
      "$PROJECT_OPT_TARGET" al::archive_one
  else
    al::archive_one "$PROJECT_OPT_TARGET"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  al::main "$@"
fi
