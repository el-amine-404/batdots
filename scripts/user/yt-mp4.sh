#!/usr/bin/env bash
# scripts/user/yt-mp4.sh -- Download video with yt-dlp as a merged MP4.
#
# Best-available MP4 video + M4A audio muxed into a single .mp4 (falling back to
# any best video+audio pair when no native MP4/M4A exists). The merge step needs
# ffmpeg; without it yt-dlp silently degrades to a single pre-muxed stream.
#
# Output dir: $DOTFILES_YT_MP4_DIR (see local/env.sh), default ~/Videos/Youtube.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

TARGET_DIR=""

ytmp4::usage() {
  cat << EOF
Usage: $(basename "$0") <url> [url...]

Download each URL's video as a merged MP4 (best MP4 video + M4A audio) into the
target directory. Playlists are expanded.

Target: \$DOTFILES_YT_MP4_DIR (default: ~/Videos/Youtube)
EOF
}

ytmp4::resolve_target() {
  TARGET_DIR="${DOTFILES_YT_MP4_DIR:?DOTFILES_YT_MP4_DIR must be set in local/env.sh}"
  dir::create "$TARGET_DIR" || log::fatal "cannot create target dir: $TARGET_DIR"
}

ytmp4::download() {
  local url="$1"
  log::info "Downloading: $url"
  yt-dlp \
    --no-cache-dir --geo-bypass \
    -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b" \
    --merge-output-format mp4 \
    --restrict-filenames --yes-playlist \
    -o "${TARGET_DIR}/%(title)s.%(ext)s" \
    -- "$url"
}

main() {
  banner::print "yt-mp4"
  case "${1:-}" in
    -h | --help)
      ytmp4::usage
      exit 0
      ;;
  esac
  [[ $# -ge 1 ]] || {
    ytmp4::usage >&2
    log::fatal "at least one URL is required"
  }
  os::check_dependency yt-dlp ffmpeg || exit 1
  ytmp4::resolve_target

  local url
  for url in "$@"; do
    ytmp4::download "$url"
  done
  log::info "Done -> $TARGET_DIR/"
}

main "$@"
