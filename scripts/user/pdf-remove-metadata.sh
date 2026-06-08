#!/usr/bin/env bash
# scripts/user/pdf-remove-metadata.sh -- Strip metadata from PDFs before sharing.
#
# Clears the document Info dict and XMP packet (author, title, producer, dates,
# GPS, ...) with exiftool, rebuilds the file with qpdf to drop the orphaned
# objects that can still hold those tags, and linearizes the result for fast
# web view. Each PDF is cleaned IN PLACE; the original is archived under
# ORIGINAL_PDF/ (mirroring its path) for rollback. Re-runs skip files already
# cleaned, corrupt files go to BAD_PDF/. Tidy archived originals later with
# 'purge-originals pdfs'.
#
# NOTE: metadata embedded *inside* page images (e.g. EXIF in an embedded JPEG)
# is NOT reached by this. To guarantee that too, use:
#     pdf-sanitize.sh --paranoid   (rasterizes every page)
#
# Usage:
#   pdf-remove-metadata.sh                 clean every PDF in the current dir (in place)
#   pdf-remove-metadata.sh FILE...         clean the given files
#   pdf-remove-metadata.sh DIR             clean every PDF in DIR
#
# Options:
#   -r, --recursive    Recurse into subdirectories of any DIR target
#   -n, --dry-run      List what would be cleaned, write nothing
#   -h, --help         Show this help message
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

PMETA_RECURSIVE=0
declare -a PMETA_POS=()

pmeta::usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' \
    "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")"
}

pmeta::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --recursive) PMETA_RECURSIVE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        pmeta::usage
        exit 0
        ;;
      --)
        shift
        PMETA_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        pmeta::usage >&2
        exit 2
        ;;
      *) PMETA_POS+=("$1") ;;
    esac
    shift
  done
}

pmeta::list_in_dir() {
  local dir="$1" maxdepth=(-maxdepth 1)
  [[ $PMETA_RECURSIVE == 1 ]] && maxdepth=()
  # Prune our archive/quarantine dirs so a recursive re-run never re-cleans an
  # already-archived original.
  find "$dir" "${maxdepth[@]}" \
    -type d \( -name ORIGINAL_PDF -o -name BAD_PDF -o -name QUARANTINE \) -prune -o \
    -type f -iname '*.pdf' -print0
}

pmeta::collect() {
  if [[ ${#PMETA_POS[@]} -eq 0 ]]; then
    pmeta::list_in_dir .
    return
  fi
  local a
  for a in "${PMETA_POS[@]}"; do
    if [[ -d $a ]]; then
      pmeta::list_in_dir "$a"
    elif [[ -f $a ]]; then
      printf '%s\0' "$a"
    else
      log::warn "not a file or directory: $a"
    fi
  done
}

pmeta::run() {
  local found=0 ok=0 skipped=0 failed=0 f tmp
  while IFS= read -r -d '' f; do
    found=1
    # Idempotency: skip only if THIS file was already metadata-stripped (per-tool
    # stamp), so this composes with compress/sanitize instead of blocking them.
    if pdf::already_processed ORIGINAL_PDF "$f" metastripped; then
      log::info "skip (already cleaned): $f"
      skipped=$((skipped + 1))
      continue
    fi
    if [[ ${DRY_RUN:-0} == 1 ]]; then
      log::info "[dry-run] would clean in place: $f  (original -> ORIGINAL_PDF/)"
      ok=$((ok + 1))
      continue
    fi
    # Corrupt/invalid -> BAD_PDF, then skip.
    pdf::validate "$f" || {
      failed=$((failed + 1))
      continue
    }
    tmp=$(mktemp --tmpdir "pdf-meta-XXXXXX.pdf") || {
      failed=$((failed + 1))
      continue
    }
    if pdf::remove_metadata "$f" "$tmp" && pdf::commit_in_place ORIGINAL_PDF "$f" "$tmp" metastripped; then
      ok=$((ok + 1))
    else
      rm -f -- "$tmp"
      failed=$((failed + 1))
    fi
  done < <(pmeta::collect)

  [[ $found == 1 ]] || {
    log::warn "No PDFs to clean"
    return 0
  }
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${ok} to clean, ${skipped} skipped"
  else
    log::info "Done: ${ok} cleaned in place, ${skipped} skipped, ${failed} failed"
  fi
}

main() {
  banner::print "pdf clean metadata"
  pmeta::parse_args "$@"
  os::check_dependency qpdf exiftool file || exit 1
  pmeta::run
}

main "$@"
