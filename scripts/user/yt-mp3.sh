#!/usr/bin/env bash
# scripts/user/yt-mp3.sh -- Download audio with yt-dlp as a tagged MP3.
#
# Best-available audio re-encoded to MP3 (V0) with embedded metadata and a
# cover thumbnail, and SponsorBlock "music_offtopic" segments removed -- a clean,
# tagged file ready for the music intake pipeline. The source (YouTube) is lossy,
# so this is not a lossless path; it just produces the cleanest possible MP3.
#
# Output dir: $DOTFILES_YT_MP3_DIR (see local/env.sh), default ~/Music/_inbox.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

TARGET_DIR=""

ytmp3::usage() {
  cat << EOF
Usage: $(basename "$0") <url> [url...]

Download each URL's audio as a tagged MP3 (embedded metadata + cover art,
SponsorBlock music_offtopic removed) into the inbox directory. Playlists are
expanded.

Inbox: \$DOTFILES_YT_MP3_DIR (default: ~/Music/_inbox)
EOF
}

ytmp3::resolve_inbox() {
  TARGET_DIR="${DOTFILES_YT_MP3_DIR:?DOTFILES_YT_MP3_DIR must be set in local/env.sh}"
  dir::create "$TARGET_DIR" || log::fatal "cannot create inbox dir: $TARGET_DIR"
}

ytmp3::download() {
  local url="$1"
  log::info "Downloading: $url"
  yt-dlp \
    --no-cache-dir --geo-bypass \
    --extract-audio --audio-format mp3 --audio-quality 0 \
    --embed-metadata --embed-thumbnail --convert-thumbnails jpg \
    --sponsorblock-remove music_offtopic \
    --restrict-filenames --yes-playlist \
    -o "${TARGET_DIR}/%(artist,uploader)s - %(track,title)s.%(ext)s" \
    -- "$url"
}

main() {
  banner::print "yt-mp3"
  case "${1:-}" in
    -h | --help)
      ytmp3::usage
      exit 0
      ;;
  esac
  [[ $# -ge 1 ]] || {
    ytmp3::usage >&2
    log::fatal "at least one URL is required"
  }
  os::check_dependency yt-dlp ffmpeg || exit 1
  ytmp3::resolve_inbox

  local url
  for url in "$@"; do
    ytmp3::download "$url"
  done
  log::info "Done -> $TARGET_DIR/"
}

main "$@"
