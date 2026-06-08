#!/usr/bin/env bash
# scripts/user/video-fix.sh -- Repair videos that fail validation.
#
# For each target that is already a valid video, does nothing. For broken ones
# (truncated, corrupt index, raw elementary stream, missing duration) it tries
# a stream-copy remux first, then a corrupt-tolerant re-encode. Recovered files
# land in REPAIRED/; originals are left untouched.
#
# Usage:
#   video-fix.sh                 try to repair every video in the current dir
#   video-fix.sh FILE...         repair the given files
#   video-fix.sh DIR             repair every video in DIR (e.g. BAD_VIDEO)
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

vfix::collect() {
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

vfix::run() {
  local found=0 valid=0 fixed=0 failed=0 f
  while IFS= read -r -d '' f; do
    found=1
    if video::is_real_video "$f" > /dev/null 2>&1; then
      log::info "already valid, skipping: $f"
      valid=$((valid + 1))
    elif video::repair "$f"; then
      fixed=$((fixed + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(vfix::collect "$@")

  [[ $found == 1 ]] || {
    log::warn "No videos found"
    return 0
  }
  log::info "Done: $fixed repaired -> REPAIRED/, $valid already valid, $failed unrecoverable"
}

vfix::main() {
  banner::print "video fix"
  os::check_dependency ffmpeg ffprobe || exit 1
  vfix::run "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vfix::main "$@"
fi
