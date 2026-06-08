#!/usr/bin/env bash
# scripts/user/bulk-rename-sequential.sh -- Rename files in a directory to a
# zero-padded running number, optionally with a base name and a start offset.
#
# Examples:
#   bulk-rename-sequential 3                 -> 001.ext, 002.ext, ...
#   bulk-rename-sequential 3 vacation        -> 001_vacation.ext, ...
#   bulk-rename-sequential --start 5 3       -> 005.ext, 006.ext, ...
#   bulk-rename-sequential 3 art ~/pics      -> renames files in ~/pics

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

BRS_START=1
BRS_PADDING=""
BRS_NAME=""
BRS_DIR="."
declare -a BRS_POS=()

brs::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] <padding> [name] [directory]

Rename every file in a directory to a zero-padded sequential number.

Arguments:
  <padding>      Number of digits (e.g. 3 -> 001, 002, ...).
  [name]         Optional base name appended after the number (NNN_name.ext).
  [directory]    Directory to operate on (default: current directory).

Options:
  -s, --start N  Start numbering at N (default: 1).
  -n, --dry-run  Show what would be renamed without making changes.
  -h, --help     Show this help message.
EOF
}

brs::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s | --start)
        BRS_START="${2:?--start requires a number}"
        shift 2
        ;;
      -n | --dry-run)
        export DRY_RUN=1
        shift
        ;;
      -h | --help)
        brs::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        brs::usage >&2
        exit 1
        ;;
      *)
        BRS_POS+=("$1")
        shift
        ;;
    esac
  done

  BRS_PADDING="${BRS_POS[0]:-}"
  BRS_NAME="${BRS_POS[1]:-}"
  BRS_DIR="${BRS_POS[2]:-.}"
}

brs::validate() {
  [[ $BRS_PADDING =~ ^[0-9]+$ ]] || {
    log::error "padding must be a number (got '${BRS_PADDING:-}')"
    brs::usage >&2
    exit 1
  }
  [[ $BRS_START =~ ^[0-9]+$ ]] || log::fatal "--start must be a number (got '$BRS_START')"
  [[ -d $BRS_DIR ]] || log::fatal "Not a directory: $BRS_DIR"
}

brs::run() {
  local pattern="%0${BRS_PADDING}d"
  [[ -n $BRS_NAME ]] && pattern+="_${BRS_NAME}"

  (
    cd "$BRS_DIR"
    local files=()
    mapfile -t files < <(find . -maxdepth 1 -type f -not -path '*/.*' | sort)
    if ((${#files[@]} == 0)); then
      log::warn "No files found in $BRS_DIR."
      exit 0
    fi

    log::info "Renaming ${#files[@]} file(s) in $BRS_DIR starting at $BRS_START..."
    [[ ${DRY_RUN:-0} == 1 ]] && log::warn "DRY-RUN: no changes will be made."
    file::rename_sequential --start "$BRS_START" "$pattern" "${files[@]}"
  )
}

main() {
  brs::parse_args "$@"
  brs::validate
  banner::print "bulk rename"
  brs::run
  log::info "Sequential rename complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
