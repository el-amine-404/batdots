#!/usr/bin/env bash
# scripts/user/video-concat-same.sh -- Losslessly join same-codec videos.
#
# Stream-copies (no re-encode) every *.EXT in the current directory into one
# file. All inputs must share codec/resolution/format -- for mixed inputs use
# video-concat-different.sh. Output lands in MERGED/.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

vcs::usage() {
  log::info "Usage: $(basename "$0") <extension>"
  log::info "Example: $(basename "$0") mp4"
  exit 1
}

# Writes an ffmpeg concat list for every *.ext in cwd; single quotes in names
# are escaped per the concat-demuxer rule (' -> '\'').
vcs::build_list() {
  local ext="$1" list="$2" f esc found=1
  shopt -s nullglob
  for f in ./*."$ext"; do
    [[ -f $f ]] || continue
    esc="${f//\'/\'\\\'\'}"
    printf "file '%s'\n" "$PWD/${esc#./}" >> "$list"
    found=0
  done
  shopt -u nullglob
  return "$found"
}

vcs::concat() {
  local ext="$1" list output
  dir::create MERGED
  output=$(string::next_available_path "MERGED/output-concat.${ext}")

  list=$(mktemp)
  if ! vcs::build_list "$ext" "$list"; then
    log::error "No files with extension .${ext} found."
    rm -f "$list"
    return 1
  fi

  log::info "Concatenating all *.${ext} files -> ${output}"
  ffmpeg -nostdin -hide_banner -loglevel warning -y \
    -f concat -safe 0 -i "$list" -c copy -- "$output"
  rm -f "$list"
  log::info "Merged video saved to ${output}"
}

vcs::main() {
  os::check_dependency ffmpeg || exit 1
  [[ $# -eq 1 ]] || vcs::usage
  vcs::concat "$1"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vcs::main "$@"
fi
