#!/usr/bin/env bash
# scripts/user/pdf-compress.sh -- Shrink PDFs with Ghostscript, balancing size
# against quality. Each PDF is compressed IN PLACE; the original is archived
# under ORIGINAL_PDF/ (mirroring its path, so same-named files in different dirs
# never collide) for rollback. Re-runs skip files already compressed, and corrupt
# files are moved to BAD_PDF/. Tidy archived originals later with
# 'purge-originals pdfs'.
#
# Quality presets (Ghostscript -dPDFSETTINGS), smallest -> largest:
#   1 screen    72 dpi   -- smallest, on-screen viewing
#   2 ebook    150 dpi   -- good for sharing / reading (default)
#   3 printer  300 dpi   -- print quality
#   4 prepress 300 dpi   -- color-preserving, largest
#
# Usage:
#   pdf-compress.sh                    compress every PDF in the current dir (in place)
#   pdf-compress.sh FILE...            compress the given files
#   pdf-compress.sh DIR                compress every PDF in DIR
#
# Options:
#   -q, --quality N    Preset 1-4 (default: 2)
#   -r, --recursive    Recurse into subdirectories of any DIR target
#   -n, --dry-run      List what would be compressed, write nothing
#   -h, --help         Show this help message
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

PCMP_QUALITY=2
PCMP_RECURSIVE=0
declare -a PCMP_POS=()

pcmp::usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' \
    "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")"
}

pcmp::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -q | --quality)
        shift
        PCMP_QUALITY="${1:?--quality needs a value 1-4}"
        ;;
      -r | --recursive) PCMP_RECURSIVE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        pcmp::usage
        exit 0
        ;;
      --)
        shift
        PCMP_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        pcmp::usage >&2
        exit 2
        ;;
      *) PCMP_POS+=("$1") ;;
    esac
    shift
  done
  [[ $PCMP_QUALITY =~ ^[1-4]$ ]] || log::fatal "--quality must be 1-4 (got '$PCMP_QUALITY')"
}

pcmp::list_in_dir() {
  local dir="$1" maxdepth=(-maxdepth 1)
  [[ $PCMP_RECURSIVE == 1 ]] && maxdepth=()
  # Prune our archive/quarantine dirs so a recursive re-run never re-compresses
  # an already-archived original.
  find "$dir" "${maxdepth[@]}" \
    -type d \( -name ORIGINAL_PDF -o -name BAD_PDF -o -name QUARANTINE \) -prune -o \
    -type f -iname '*.pdf' -print0
}

pcmp::collect() {
  if [[ ${#PCMP_POS[@]} -eq 0 ]]; then
    pcmp::list_in_dir .
    return
  fi
  local a
  for a in "${PCMP_POS[@]}"; do
    if [[ -d $a ]]; then
      pcmp::list_in_dir "$a"
    elif [[ -f $a ]]; then
      printf '%s\0' "$a"
    else
      log::warn "not a file or directory: $a"
    fi
  done
}

pcmp::run() {
  local found=0 ok=0 skipped=0 failed=0 f tmp
  while IFS= read -r -d '' f; do
    found=1
    # Idempotency: skip only if THIS file was already compressed (per-tool stamp),
    # so a sanitize->compress chain still compresses the sanitized file.
    if pdf::already_processed ORIGINAL_PDF "$f" compressed; then
      log::info "skip (already compressed): $f"
      skipped=$((skipped + 1))
      continue
    fi
    if [[ ${DRY_RUN:-0} == 1 ]]; then
      log::info "[dry-run] would compress in place (q${PCMP_QUALITY}): $f  (original -> ORIGINAL_PDF/)"
      ok=$((ok + 1))
      continue
    fi
    # Corrupt/invalid -> BAD_PDF, then skip.
    pdf::validate "$f" || {
      failed=$((failed + 1))
      continue
    }
    tmp=$(mktemp --tmpdir "pdf-cmp-XXXXXX.pdf") || {
      failed=$((failed + 1))
      continue
    }
    if pdf::compress "$f" "$tmp" "$PCMP_QUALITY" && pdf::commit_in_place ORIGINAL_PDF "$f" "$tmp" compressed; then
      ok=$((ok + 1))
    else
      rm -f -- "$tmp"
      failed=$((failed + 1))
    fi
  done < <(pcmp::collect)

  [[ $found == 1 ]] || {
    log::warn "No PDFs to compress"
    return 0
  }
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${ok} to compress, ${skipped} skipped"
  else
    log::info "Done: ${ok} compressed, ${skipped} skipped, ${failed} failed"
  fi
}

main() {
  banner::print "pdf compress"
  pcmp::parse_args "$@"
  os::check_dependency gs qpdf file || exit 1
  pcmp::run
}

main "$@"
