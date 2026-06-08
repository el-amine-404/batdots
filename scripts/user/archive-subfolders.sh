#!/usr/bin/env bash
# scripts/user/archive-subfolders.sh -- Archive a folder, detecting tags
# for sensible exclusions but never refusing.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

as::archive_one() {
  archive::project project::is_any "$1"
}

as::main() {
  banner::print "compress folders"
  project::parse_args "$@" || exit 1
  if ((PROJECT_OPT_RECURSIVE)); then
    # Recursive mode here means: archive each immediate subdirectory.
    local sub
    for sub in "$PROJECT_OPT_TARGET"/*/; do
      [[ -d $sub ]] || continue
      as::archive_one "${sub%/}"
    done
  else
    as::archive_one "$PROJECT_OPT_TARGET"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  as::main "$@"
fi
