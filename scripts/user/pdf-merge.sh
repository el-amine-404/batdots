#!/usr/bin/env bash
# scripts/user/pdf-merge.sh -- Merge PDFs into one with Ghostscript.
#
# With explicit files the given order is kept; with a directory (or no argument,
# meaning the current dir) the PDFs are merged in natural-sorted name order.
#
# Usage:
#   pdf-merge.sh                       merge every PDF in the current dir (sorted)
#   pdf-merge.sh FILE...               merge the given files, in order
#   pdf-merge.sh DIR                   merge every PDF in DIR (sorted)
#
# Options:
#   -o, --output FILE   Output path (default: merged.pdf)
#   -n, --dry-run       List the merge order, write nothing
#   -h, --help          Show this help message
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

PMRG_OUTPUT="merged.pdf"
declare -a PMRG_POS=()
declare -a PMRG_INPUTS=()

pmrg::usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' \
    "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")"
}

pmrg::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o | --output)
        shift
        PMRG_OUTPUT="${1:?--output needs a path}"
        ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        pmrg::usage
        exit 0
        ;;
      --)
        shift
        PMRG_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        pmrg::usage >&2
        exit 2
        ;;
      *) PMRG_POS+=("$1") ;;
    esac
    shift
  done
}

pmrg::collect() {
  local f
  # Explicit-file mode: every positional is a file -- keep the given order.
  if [[ ${#PMRG_POS[@]} -gt 0 ]] && [[ -f ${PMRG_POS[0]} ]]; then
    for f in "${PMRG_POS[@]}"; do
      [[ -f $f ]] || log::fatal "not a file: $f (mix files and dirs not supported)"
      PMRG_INPUTS+=("$f")
    done
    return
  fi

  # Directory mode: at most one positional, a directory (default: cwd).
  [[ ${#PMRG_POS[@]} -le 1 ]] || log::fatal "pass PDF files, or a single directory -- not both"
  local dir="${PMRG_POS[0]:-.}"
  [[ -d $dir ]] || log::fatal "not a directory: $dir"
  while IFS= read -r -d '' f; do
    PMRG_INPUTS+=("$f")
  done < <(find "$dir" -maxdepth 1 -type f -iname '*.pdf' -print0 | sort -Vz)

  [[ ${#PMRG_INPUTS[@]} -ge 2 ]] || log::fatal "need at least 2 PDFs to merge (found ${#PMRG_INPUTS[@]})"
}

main() {
  banner::print "pdf merge"
  pmrg::parse_args "$@"
  os::check_dependency gs || exit 1
  pmrg::collect

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${#PMRG_INPUTS[@]} file(s) -> $PMRG_OUTPUT, in this order:"
    local f
    for f in "${PMRG_INPUTS[@]}"; do log::info "  $f"; done
    return 0
  fi

  log::info "Found ${#PMRG_INPUTS[@]} files to merge."
  pdf::merge "$PMRG_OUTPUT" "${PMRG_INPUTS[@]}"
}

main "$@"
