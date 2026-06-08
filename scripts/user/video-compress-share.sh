#!/usr/bin/env bash
# scripts/user/video-compress-share.sh -- Compress videos into small, metadata-
# stripped H.264/MP4 copies for sharing (chat apps, uploads, phones).
#
# Unlike video-archive (HEVC/MKV, preserves everything), this targets size and
# universal playback: H.264 + AAC, first audio track only, all metadata wiped
# for privacy, then capture date re-applied so timelines stay correct.
# Originals are moved to ORIGINAL_VIDEOS/ -- never deleted.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

vshare::run() {
  local dir="${1:-.}" found=0 ok=0 failed=0 f
  while IFS= read -r -d '' f; do
    found=1
    if video::compress_share "$f"; then
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
  log::info "Done: $ok compressed, $failed failed -> *.mp4 (originals in ORIGINAL_VIDEOS/)"
}

vshare::main() {
  banner::print "video compress-share"
  os::check_dependency ffmpeg ffprobe exiftool || exit 1
  vshare::run "${1:-.}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vshare::main "$@"
fi
