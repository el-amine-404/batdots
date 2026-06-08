#!/usr/bin/env bash
# scripts/user/video-trimmer.sh -- Trim a video to a [start, end] window.
#
# Single accurate re-encode (seek points are decoded, not keyframe-snapped).
# Result lands in TRIMMED/; the original is moved to ORIGINAL/.
#
# Usage: video-trimmer.sh <videoFile> <hh:mm:ss[.xxx]> <hh:mm:ss[.xxx]>
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

vtrim::usage() {
  log::info "Usage: $(basename "$0") <videoFile> <hh:mm:ss[.xxx]> <hh:mm:ss[.xxx]>"
  exit 1
}

vtrim::trim() {
  local input="$1" start="$2" end="$3"
  local base output crf
  base=$(basename -- "$input")
  output="TRIMMED/${base%.*}.mp4"
  crf="${DOTFILES_VIDEO_TRIM_CRF:?DOTFILES_VIDEO_TRIM_CRF must be set in local/env.sh}"

  dir::create TRIMMED
  dir::create ORIGINAL

  log::info "Trimming $base from $start to $end..."
  ffmpeg -nostdin -hide_banner -loglevel warning -y \
    -i "$input" -ss "$start" -to "$end" \
    -c:v libx264 -preset veryslow -crf "$crf" -pix_fmt yuv420p \
    -c:a aac -b:a 160k \
    -movflags +faststart -- "$output"

  file::move "$input" "ORIGINAL/$base"
  log::info "Trimmed -> $output (original moved to ORIGINAL/)"
}

vtrim::main() {
  os::check_dependency ffmpeg || exit 1
  [[ $# -eq 3 ]] || vtrim::usage

  file::exists "$1" || log::fatal "File not found: $1"
  video::is_real_video "$1" || log::fatal "Invalid video file: $1"
  vtrim::trim "$1" "$2" "$3"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vtrim::main "$@"
fi
