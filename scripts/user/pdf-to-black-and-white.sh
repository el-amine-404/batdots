#!/usr/bin/env bash
# scripts/user/pdf-to-black-and-white.sh -- Convert PDFs to grayscale with
# Ghostscript. For each input it writes <name>_bw.pdf beside it (originals
# untouched). Useful for shrinking color scans and for cheaper printing.
#
# Usage:
#   pdf-to-black-and-white.sh                 convert every PDF in the current dir
#   pdf-to-black-and-white.sh FILE...         convert the given files
#   pdf-to-black-and-white.sh DIR             convert every PDF in DIR
#
# Options:
#   -r, --recursive    Recurse into subdirectories of any DIR target
#   -n, --dry-run      List what would be converted, write nothing
#   -h, --help         Show this help message
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

PBW_RECURSIVE=0
declare -a PBW_POS=()

pbw::usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' \
    "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")"
}

pbw::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --recursive) PBW_RECURSIVE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        pbw::usage
        exit 0
        ;;
      --)
        shift
        PBW_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        pbw::usage >&2
        exit 2
        ;;
      *) PBW_POS+=("$1") ;;
    esac
    shift
  done
}

pbw::list_in_dir() {
  local dir="$1" maxdepth=(-maxdepth 1)
  [[ $PBW_RECURSIVE == 1 ]] && maxdepth=()
  find "$dir" "${maxdepth[@]}" -type f -iname '*.pdf' \! -iname '*_bw.pdf' -print0
}

pbw::collect() {
  if [[ ${#PBW_POS[@]} -eq 0 ]]; then
    pbw::list_in_dir .
    return
  fi
  local a
  for a in "${PBW_POS[@]}"; do
    if [[ -d $a ]]; then
      pbw::list_in_dir "$a"
    elif [[ -f $a ]]; then
      printf '%s\0' "$a"
    else
      log::warn "not a file or directory: $a"
    fi
  done
}

pbw::run() {
  local found=0 ok=0 skipped=0 failed=0 f out
  while IFS= read -r -d '' f; do
    found=1
    out="${f%.*}_bw.pdf"
    # Idempotency: never re-convert our own output, and never overwrite an
    # existing grayscale copy -- a re-run is a no-op.
    if [[ ${f,,} == *_bw.pdf ]]; then
      log::info "skip (already grayscale): $f"
      skipped=$((skipped + 1))
      continue
    fi
    if [[ -e $out ]]; then
      log::info "skip (grayscale copy exists): $out"
      skipped=$((skipped + 1))
      continue
    fi
    if [[ ${DRY_RUN:-0} == 1 ]]; then
      log::info "[dry-run] would convert: $f -> $out"
      ok=$((ok + 1))
      continue
    fi
    if pdf::to_bw "$f" "$out"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(pbw::collect)

  [[ $found == 1 ]] || {
    log::warn "No PDFs to convert"
    return 0
  }
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${ok} to convert, ${skipped} skipped"
  else
    log::info "Done: ${ok} converted, ${skipped} skipped, ${failed} failed"
  fi
}

main() {
  banner::print "pdf to b&w"
  pbw::parse_args "$@"
  os::check_dependency gs || exit 1
  pbw::run
}

main "$@"
