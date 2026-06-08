#!/usr/bin/env bash
# scripts/user/photo-video-rename-exif.sh -- Rename photos/videos by capture date.
#
# Renames in place to an ISO-like "YYYY-MM-DD__HHh-MMm-SSs" stem (colons aren't
# legal in filenames), with a "-N" suffix on collisions. Files are NEVER moved
# between folders -- directory structure stays exactly as you organized it.
# Falls back to file mtime when no date metadata exists.
# Dependencies: exiftool (required), detox (optional, tidies odd characters)
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

pvr::cleanup_filenames() {
  if command::exists detox; then
    log::info "Cleaning up filenames with detox..."
    detox -rv -- .
  else
    log::warn "detox is not installed. Skipping filename cleanup."
  fi
}

pvr::rename_all() {
  log::info "Renaming files based on capture date..."
  # Assignments apply lowest-to-highest priority (last existing tag wins).
  # FileModifyDate (mtime) is the always-present fallback so screenshots and
  # EXIF-stripped downloads still get renamed instead of skipped. %%-c handles
  # collisions; -ext+ AVI re-includes AVI which exiftool skips for some tags.
  exiftool \
    -ext+ AVI \
    -d "%Y-%m-%d__%Hh-%Mm-%Ss%%-c.%%le" \
    '-filename<FileModifyDate' \
    '-filename<GPSDateTime' \
    '-filename<MediaCreateDate' \
    '-filename<CreateDate' \
    '-filename<DateTimeOriginal' \
    -r -- .
}

pvr::main() {
  banner::print "rename by date"
  os::check_dependency exiftool || exit 1
  pvr::cleanup_filenames
  pvr::rename_all
  log::info "Done."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  pvr::main "$@"
fi
