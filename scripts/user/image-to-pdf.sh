#!/usr/bin/env bash
# scripts/user/image-to-pdf.sh -- Combine images into a single PDF.
#
# Image metadata (EXIF/GPS/profiles) is stripped before the images are embedded
# (see image::to_pdf), so a PDF you send carries no camera or location data;
# EXIF rotation is baked in first so portrait photos don't end up sideways.
#
# Selects inputs three ways:
#   - explicit files .......... image-to-pdf a.jpg b.png c.jpg   (kept in order)
#   - a directory (default cwd) image-to-pdf [DIR]               (natural-sorted)
#   - recursively ............. image-to-pdf [DIR] -r
#
# Examples:
#   image-to-pdf                              # every image in ./ -> combined_<ts>.pdf
#   image-to-pdf scan1.jpg scan2.jpg -o report.pdf
#   image-to-pdf ~/scans -r -o all.pdf

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

I2P_RECURSIVE=0
I2P_OUTPUT=""
declare -a I2P_POS=()
declare -a I2P_INPUTS=()

i2p::usage() {
  cat << EOF
Usage:
  $(basename "$0") [FILE...] [options]   combine the given images (kept in order)
  $(basename "$0") [DIR] [options]       combine every image in DIR (default: .)

Options:
  -o, --output FILE   Output PDF path (default: combined_<timestamp>.pdf)
  -r, --recursive     Recurse into subdirectories (directory mode only)
  -n, --dry-run       List the images that would be combined, write nothing
  -h, --help          Show this help message

Image EXIF/GPS metadata is stripped before embedding. In directory mode files
are ordered by natural (version) sort; explicit files keep the given order.
EOF
}

i2p::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o | --output)
        shift
        I2P_OUTPUT="${1:?--output needs a path}"
        ;;
      -r | --recursive) I2P_RECURSIVE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        i2p::usage
        exit 0
        ;;
      --)
        shift
        I2P_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        i2p::usage >&2
        exit 2
        ;;
      *) I2P_POS+=("$1") ;;
    esac
    shift
  done

  [[ -n $I2P_OUTPUT ]] || I2P_OUTPUT="combined_$(date +%s).pdf"
}

i2p::require_deps() {
  command::exists convert \
    || log::fatal "ImageMagick 'convert' not found -- install the 'imagemagick' package"
}

i2p::is_image() {
  file --mime-type -b -- "$1" 2> /dev/null | grep -q "^image/"
}

i2p::all_regular_files() {
  local p
  for p in "$@"; do
    [[ -f $p ]] || return 1
  done
}

i2p::collect_inputs() {
  local f
  # Explicit-file mode: every positional is a file -- keep the given page order.
  if [[ ${#I2P_POS[@]} -gt 0 ]] && i2p::all_regular_files "${I2P_POS[@]}"; then
    for f in "${I2P_POS[@]}"; do
      if i2p::is_image "$f"; then
        I2P_INPUTS+=("$f")
      else
        log::warn "Skipping (not an image): $f"
      fi
    done
  else
    # Directory mode: at most one positional, which must be a directory.
    [[ ${#I2P_POS[@]} -le 1 ]] || {
      log::error "Pass image files, or a single directory to scan -- not both"
      i2p::usage >&2
      exit 2
    }
    local dir="${I2P_POS[0]:-.}"
    [[ -d $dir ]] || log::fatal "Not a directory: $dir"

    local maxdepth=(-maxdepth 1)
    [[ $I2P_RECURSIVE == 1 ]] && maxdepth=()

    while IFS= read -r -d '' f; do
      if i2p::is_image "$f"; then
        I2P_INPUTS+=("$f")
      fi
    done < <(find "$dir" "${maxdepth[@]}" -type f -print0 | sort -Vz)
  fi

  [[ ${#I2P_INPUTS[@]} -gt 0 ]] || log::fatal "No image files found."
}

main() {
  banner::print "image to pdf"
  i2p::parse_args "$@"
  i2p::require_deps
  i2p::collect_inputs

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${#I2P_INPUTS[@]} image(s) -> $I2P_OUTPUT (metadata stripped):"
    local f
    for f in "${I2P_INPUTS[@]}"; do
      log::info "  $f"
    done
    return 0
  fi

  image::to_pdf "$I2P_OUTPUT" "${I2P_INPUTS[@]}"
}

main "$@"
