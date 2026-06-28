#!/usr/bin/env bash
# scripts/user/sanitize-media.sh -- Fast, stream-copy sanitization of media files.
#
# Discards subtitles, data, and metadata from video files in-place using ffmpeg stream copy.
# Faster than re-encoding.
#
# Usage:
#   sanitize-media.sh [DIR_OR_FILE]
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

DEFAULT_SOURCE="/mnt/storage/data/media"

sanmedia::collect() {
  local target="${1:-$DEFAULT_SOURCE}"
  if [[ -f $target ]]; then
    printf '%s\0' "$target"
  elif [[ -d $target ]]; then
    find "$target" -type f -print0
  else
    log::warn "Target path does not exist: $target"
  fi
}

sanmedia::process_file() {
  local file="$1"
  local temp="${file}.sanitized.mkv"

  log::info "Sanitizing: $(basename "$file")..."

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would sanitize $file via stream copy"
    return 0
  fi

  if $SUDO_CMD ffmpeg -nostdin -i "$file" -map 0:v -map 0:a -sn -dn -map_metadata -1 -c copy "$temp" -y -loglevel error; then
    $SUDO_CMD mv "$temp" "$file"
    log::info "  Successfully sanitized $file"
    return 0
  else
    log::error "  Failed to sanitize $file"
    $SUDO_CMD rm -f "$temp"
    return 1
  fi
}

sanmedia::run() {
  local target="${1:-}"
  local found=0 ok=0 failed=0 f

  while IFS= read -r -d '' f; do
    found=1
    if sanmedia::process_file "$f"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(sanmedia::collect "$target")

  if [[ $found -eq 0 ]]; then
    log::warn "No media files found to sanitize."
    return 0
  fi

  log::info "Done: $ok successfully sanitized, $failed failed."
}

main() {
  banner::print "sanitize media"
  os::check_dependency ffmpeg || exit 1
  sanmedia::run "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
