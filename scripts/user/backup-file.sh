#!/usr/bin/env bash
# scripts/user/backup-file.sh -- Create a .bak copy of a file.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

bak::usage() {
  cat << EOF
Usage: $(basename -- "$0") <file>

Create a .bak copy of <file> alongside it. Existing backups are kept
(numbered .bak.~1~, .bak.~2~, ...), never overwritten.
EOF
}

bak::main() {
  case "${1:-}" in
    -h | --help)
      bak::usage
      exit 0
      ;;
  esac
  if [[ $# -ne 1 ]]; then
    bak::usage >&2
    exit 1
  fi
  file::copy "$1" "${1}.bak"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  bak::main "$@"
fi
