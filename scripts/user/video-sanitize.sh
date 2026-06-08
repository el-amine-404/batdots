#!/usr/bin/env bash
# scripts/user/video-sanitize.sh -- Maximum-sanitize untrusted videos.
#
# For files you DON'T trust (downloaded, received from others). Runs a ClamAV
# signature scan, then fully re-encodes video AND audio, dropping every non-A/V
# stream and all metadata -- nothing from the original container survives as a
# bitstream, neutralizing polyglots, embedded attachments and metadata payloads.
#
# This intentionally loses Atmos / lossless audio: do NOT run it on your own
# footage -- use video-archive.sh for that. Clean copies land in CLEAN/,
# originals are moved to QUARANTINE/.
#
# Usage:
#   video-sanitize.sh                 sanitize every video in the current dir
#   video-sanitize.sh FILE...         sanitize the given files
#   video-sanitize.sh DIR             sanitize every video in DIR
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

vsan::collect() {
  if [[ $# -eq 0 ]]; then
    video::list_in_dir .
    return
  fi
  local a
  for a in "$@"; do
    if [[ -d $a ]]; then
      video::list_in_dir "$a"
    elif [[ -f $a ]]; then
      printf '%s\0' "$a"
    else
      log::warn "not a file or directory: $a"
    fi
  done
}

vsan::run() {
  local found=0 ok=0 failed=0 f
  while IFS= read -r -d '' f; do
    found=1
    if video::sanitize "$f"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(vsan::collect "$@")

  [[ $found == 1 ]] || {
    log::warn "No videos to sanitize"
    return 0
  }
  log::info "Done: $ok sanitized -> CLEAN/, $failed flagged/failed (originals in QUARANTINE/)"
}

vsan::main() {
  banner::print "video sanitize"
  os::check_dependency ffmpeg ffprobe || exit 1
  command::exists clamscan || log::warn "clamscan not installed -- signature scan will be skipped"
  vsan::run "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vsan::main "$@"
fi
