#!/usr/bin/env bash
# scripts/user/video-archive.sh -- Storage-optimize videos into an HEVC/MKV archive.
#
# Re-encodes the video stream to HEVC while copying every audio and subtitle
# track untouched (Atmos / multichannel / multiple tracks survive), keeping
# source resolution, bit depth and metadata. Originals are moved to
# ORIGINAL_VIDEOS/ -- never deleted. Quality/speed via env:
#   DOTFILES_VIDEO_ARCHIVE_CRF (default 22), DOTFILES_VIDEO_ARCHIVE_PRESET (medium)
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

varch::run() {
  local dir="${1:-.}" found=0 ok=0 failed=0 f
  while IFS= read -r -d '' f; do
    found=1
    if video::storage_archive "$f"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
      log::warn "skipped: $f"
    fi
  done < <(video::list_in_dir "$dir")

  [[ $found == 1 ]] || {
    log::warn "No video files found in $dir"
    return 0
  }
  log::info "Done: $ok archived, $failed failed -> *.mkv (originals in ORIGINAL_VIDEOS/)"
}

varch::main() {
  banner::print "video archive"
  os::check_dependency ffmpeg ffprobe || exit 1
  varch::run "${1:-.}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  varch::main "$@"
fi
