#!/usr/bin/env bash
# scripts/user/purge-originals.sh -- Sweep workflow-archived originals to trash.
#
# The compress/convert workflows keep the source files so you can roll back:
#   image-compress            -> ORIGINAL_JPEG/ ORIGINAL_PNG/ directories
#   pdf-compress/pdf-sanitize -> ORIGINAL_PDF/ directory
#   office-to-pdf             -> original_ms_files*.tar.xz
#   *-to-pdf                  -> original_pdf_files*.tar.xz
# Once you're happy with the results, this moves those leftovers (recursively
# from the current directory) into ~/.trash-scripts/<kind> for deliberate review
# and deletion. Honors DRY_RUN via file::move.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

PO_TRASH_ROOT="$HOME/.trash-scripts"

po::usage() {
  cat << EOF
Usage: $(basename "$0") {images|office|pdfs|all}

Move workflow-archived originals from the current tree into $PO_TRASH_ROOT/<kind>:
  images   ORIGINAL_JPEG / ORIGINAL_PNG directories
  office   original_ms_files*.tar.xz archives
  pdfs     ORIGINAL_PDF directories + original_pdf_files*.tar.xz archives
  all      all of the above
EOF
}

# po::sweep <trash-subdir> <find-predicate...>
po::sweep() {
  local subdir="$1"
  shift
  local trash="${PO_TRASH_ROOT}/${subdir}"
  dir::create "$trash"

  local found=0 path
  while IFS= read -r -d '' path; do
    found=1
    file::move "$path" "$trash"
  done < <(find . -depth "$@" -print0)

  if ((found)); then
    log::info "Moved ${subdir} originals -> $trash"
  else
    log::info "No ${subdir} originals found."
  fi
}

po::images() { po::sweep IMAGES -type d \( -iname ORIGINAL_JPEG -o -iname ORIGINAL_PNG \); }
po::office() { po::sweep MS -type f -iname 'original_ms_files*.tar.xz'; }
po::pdfs() { po::sweep PDFS \( -type d -iname ORIGINAL_PDF -o -type f -iname 'original_pdf_files*.tar.xz' \); }

main() {
  local target="${1:-}"
  [[ -n $target ]] || {
    po::usage >&2
    exit 1
  }

  banner::print "purge originals"
  case "$target" in
    images) po::images ;;
    office) po::office ;;
    pdfs) po::pdfs ;;
    all)
      po::images
      po::office
      po::pdfs
      ;;
    -h | --help)
      po::usage
      exit 0
      ;;
    *)
      log::error "Unknown target: $target"
      po::usage >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
