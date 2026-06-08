#!/usr/bin/env bash
# scripts/user/image-compress.sh -- Lossy-optimize PNG and JPEG images in place.
#
# Delegates the actual work to image::optimize_png / image::optimize_jpg, which
# validate each file, archive the original under ORIGINAL_PNG/ORIGINAL_JPEG in
# the working directory (so the operator can roll back), then optimize in place.
#
# Selects inputs three ways:
#   - explicit files .......... image-compress a.png b.jpg c.jpeg
#   - a directory (default cwd) image-compress [DIR]        # non-recursive
#   - recursively ............. image-compress [DIR] -r
#
# Examples:
#   image-compress                     # every image in ./ (top level only)
#   image-compress -r                  # every image under ./ (recursive)
#   image-compress ~/Pictures -r       # recurse a specific directory
#   image-compress logo.png photo.jpg  # just these files

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

IC_RECURSIVE=0
IC_OK=0
IC_FAILED=0
IC_SKIPPED=0
declare -a IC_POS=()
declare -a IC_INPUTS=()

ic::usage() {
  cat << EOF
Usage:
  $(basename "$0") [FILE...]        optimize the given image files
  $(basename "$0") [DIR] [-r]       optimize every PNG/JPEG in DIR (default: .)

Options:
  -r, --recursive   Recurse into subdirectories (directory mode only)
  -n, --dry-run     List the images that would be optimized, change nothing
  -h, --help        Show this help message

Originals are archived under ORIGINAL_PNG/ and ORIGINAL_JPEG/ in the working
directory before each file is optimized in place.
EOF
}

ic::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --recursive) IC_RECURSIVE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        ic::usage
        exit 0
        ;;
      --)
        shift
        IC_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        ic::usage >&2
        exit 2
        ;;
      *) IC_POS+=("$1") ;;
    esac
    shift
  done
}

ic::all_regular_files() {
  local p
  for p in "$@"; do
    [[ -f $p ]] || return 1
  done
}

ic::collect_inputs() {
  # Explicit-file mode: every positional names an existing regular file.
  if [[ ${#IC_POS[@]} -gt 0 ]] && ic::all_regular_files "${IC_POS[@]}"; then
    IC_INPUTS=("${IC_POS[@]}")
    return 0
  fi

  # Directory mode: at most one positional, which must be a directory.
  [[ ${#IC_POS[@]} -le 1 ]] || {
    log::error "Pass image files, or a single directory to scan -- not both"
    ic::usage >&2
    exit 2
  }
  local dir="${IC_POS[0]:-.}"
  [[ -d $dir ]] || log::fatal "Not a directory: $dir"

  local maxdepth=(-maxdepth 1)
  [[ $IC_RECURSIVE == 1 ]] && maxdepth=()

  # Prune our own archive/quarantine dirs so a recursive re-run never
  # re-compresses an already-archived original.
  local f
  while IFS= read -r -d '' f; do
    IC_INPUTS+=("$f")
  done < <(find "$dir" "${maxdepth[@]}" \
    -type d \( -name ORIGINAL_PNG -o -name ORIGINAL_JPEG -o -name BAD_PNG -o -name BAD_JPG \) -prune -o \
    -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0)

  [[ ${#IC_INPUTS[@]} -gt 0 ]] || {
    log::info "No PNG/JPEG images found in $dir"
    exit 0
  }
}

ic::require_deps() {
  local f need_png=0 need_jpg=0
  for f in "${IC_INPUTS[@]}"; do
    case "${f##*.}" in
      [pP][nN][gG]) need_png=1 ;;
      [jJ][pP][gG] | [jJ][pP][eE][gG]) need_jpg=1 ;;
    esac
  done
  if [[ $need_png == 1 ]]; then
    os::check_dependency pngquant pngcheck file \
      || log::fatal "PNG tools missing -- install: pngquant pngcheck"
  fi
  if [[ $need_jpg == 1 ]]; then
    os::check_dependency jpegoptim jpeginfo jpegtran file \
      || log::fatal "JPEG tools missing -- install: jpegoptim jpeginfo libjpeg-progs"
  fi
}

ic::compress_one() {
  local f="$1"
  local optimizer
  case "${f##*.}" in
    [pP][nN][gG]) optimizer=image::optimize_png ;;
    [jJ][pP][gG] | [jJ][pP][eE][gG]) optimizer=image::optimize_jpg ;;
    *)
      log::warn "Skipping (not a PNG/JPEG): $f"
      IC_SKIPPED=$((IC_SKIPPED + 1))
      return 0
      ;;
  esac

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would optimize: $f"
    return 0
  fi

  if "$optimizer" "$f"; then
    IC_OK=$((IC_OK + 1))
  else
    IC_FAILED=$((IC_FAILED + 1))
  fi
}

main() {
  banner::print "image compress"
  ic::parse_args "$@"
  ic::collect_inputs
  [[ ${DRY_RUN:-0} == 1 ]] || ic::require_deps

  local f
  for f in "${IC_INPUTS[@]}"; do
    ic::compress_one "$f"
  done

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${#IC_INPUTS[@]} image(s) would be processed"
  else
    log::info "Done: $IC_OK optimized, $IC_SKIPPED skipped, $IC_FAILED failed"
  fi
}

main "$@"
