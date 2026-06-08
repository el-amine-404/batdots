#!/usr/bin/env bash
# scripts/user/pdf-to-image.sh -- Render PDF pages to images with Poppler's
# pdftoppm. Each PDF's pages are written into a sibling <name>_IMAGES/ folder
# (pg-1.png, pg-2.png, ...).
#
# Usage:
#   pdf-to-image.sh FILE...            render the given PDFs
#   pdf-to-image.sh DIR                render every PDF in DIR
#   pdf-to-image.sh                    render every PDF in the current dir
#
# Options:
#   -f, --format FMT   png (default), jpg, or tiff
#   -d, --dpi N        Resolution in DPI (default: 150)
#       --first N      First page to render (default: 1)
#       --last N       Last page to render (default: last page)
#   -r, --recursive    Recurse into subdirectories of any DIR target
#   -n, --dry-run      List what would be rendered, write nothing
#   -h, --help         Show this help message
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

P2I_FORMAT=png
P2I_DPI=150
P2I_FIRST=1
P2I_LAST=""
P2I_RECURSIVE=0
declare -a P2I_POS=()

p2i::usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' \
    "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")"
}

p2i::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f | --format)
        shift
        P2I_FORMAT="${1:?--format needs a value}"
        ;;
      -d | --dpi)
        shift
        P2I_DPI="${1:?--dpi needs a value}"
        ;;
      --first)
        shift
        P2I_FIRST="${1:?--first needs a value}"
        ;;
      --last)
        shift
        P2I_LAST="${1:?--last needs a value}"
        ;;
      -r | --recursive) P2I_RECURSIVE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        p2i::usage
        exit 0
        ;;
      --)
        shift
        P2I_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        p2i::usage >&2
        exit 2
        ;;
      *) P2I_POS+=("$1") ;;
    esac
    shift
  done
}

# Map the requested format to its pdftoppm flag(s); non-zero on unsupported.
p2i::format_flags() {
  case "${P2I_FORMAT,,}" in
    png) printf '%s\0' '-png' ;;
    jpg | jpeg) printf '%s\0%s\0%s\0' '-jpeg' '-jpegopt' 'quality=92,optimize=y' ;;
    tiff) printf '%s\0' '-tiff' ;;
    *) return 1 ;;
  esac
}

p2i::list_in_dir() {
  local dir="$1" maxdepth=(-maxdepth 1)
  [[ $P2I_RECURSIVE == 1 ]] && maxdepth=()
  find "$dir" "${maxdepth[@]}" -type f -iname '*.pdf' -print0
}

p2i::collect() {
  if [[ ${#P2I_POS[@]} -eq 0 ]]; then
    p2i::list_in_dir .
    return
  fi
  local a
  for a in "${P2I_POS[@]}"; do
    if [[ -d $a ]]; then
      p2i::list_in_dir "$a"
    elif [[ -f $a ]]; then
      printf '%s\0' "$a"
    else
      log::warn "not a file or directory: $a"
    fi
  done
}

p2i::render_one() {
  local pdf="$1"
  pdf::is_real_pdf "$pdf" || {
    log::error "skipping (not a valid PDF): $pdf"
    return 1
  }

  local outdir="${pdf%.*}_IMAGES"
  # Idempotency: if pages were already rendered for this PDF, leave them be.
  if [[ -d $outdir ]] && find "$outdir" -maxdepth 1 -type f -print -quit | grep -q .; then
    log::info "skip (already rendered): $outdir/"
    return 0
  fi

  local -a fmt
  while IFS= read -r -d '' flag; do fmt+=("$flag"); done < <(p2i::format_flags)

  local -a cmd=(pdftoppm "${fmt[@]}" -forcenum -sep - -r "$P2I_DPI" -f "$P2I_FIRST")
  [[ -n $P2I_LAST ]] && cmd+=(-l "$P2I_LAST")

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would render ${P2I_FORMAT}@${P2I_DPI}dpi: $pdf -> $outdir/"
    return 0
  fi

  dir::create "$outdir"
  log::info "rendering ${P2I_FORMAT}@${P2I_DPI}dpi: $pdf -> $outdir/"
  cmd+=("$pdf" "$outdir/pg")
  "${cmd[@]}"
}

p2i::run() {
  local found=0 ok=0 failed=0 f
  while IFS= read -r -d '' f; do
    found=1
    if p2i::render_one "$f"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(p2i::collect)

  [[ $found == 1 ]] || {
    log::warn "No PDFs to render"
    return 0
  }
  log::info "Done: ${ok} rendered, ${failed} failed"
}

main() {
  banner::print "pdf to image"
  p2i::parse_args "$@"
  p2i::format_flags > /dev/null || log::fatal "unsupported --format '$P2I_FORMAT' (use png, jpg, or tiff)"
  os::check_dependency pdftoppm || exit 1
  p2i::run
}

main "$@"
