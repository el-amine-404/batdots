#!/usr/bin/env bash
# Real-time companion to media-scan.sh: watches the media/download tree and
# scans each file the moment it finishes downloading. Run as a long-lived
# systemd user service (media-scan-watch.service); the periodic timer is the
# safety net for anything this misses.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

SCANNER="${DOTFILES_ROOT}/scripts/user/media-scan.sh"

declare -a WATCH_PATHS
if [[ -n ${DOTFILES_MEDIA_SCAN_PATHS+x} ]]; then
  WATCH_PATHS=("${DOTFILES_MEDIA_SCAN_PATHS[@]}")
elif [[ -n ${DOTFILES_HOMELAB_DATA_ROOT:-} ]]; then
  WATCH_PATHS=("$DOTFILES_HOMELAB_DATA_ROOT")
else
  WATCH_PATHS=()
fi

QUARANTINE="${DOTFILES_MEDIA_SCAN_QUARANTINE:-${DOTFILES_HOMELAB_DATA_ROOT:-$HOME}/.quarantine}"

main() {
  banner::print "media scan watch"
  command -v inotifywait > /dev/null 2>&1 || log::fatal "inotifywait not found (install inotify-tools)."
  ((${#WATCH_PATHS[@]})) || log::fatal "No watch paths -- set DOTFILES_MEDIA_SCAN_PATHS or DOTFILES_HOMELAB_DATA_ROOT."

  # Only watch paths that exist, or inotifywait aborts.
  local -a existing=()
  local p
  for p in "${WATCH_PATHS[@]}"; do
    [[ -d $p ]] && existing+=("$p")
  done
  ((${#existing[@]})) || log::fatal "None of the watch paths exist yet: ${WATCH_PATHS[*]}"

  log::info "Watching for new files under: ${existing[*]}"

  # close_write: a file finished being written; moved_to: qBittorrent's atomic
  # move from the incomplete dir into place. Exclude the quarantine subtree so
  # moving a hit there never re-triggers a scan loop.
  inotifywait -m -r -q \
    -e close_write -e moved_to \
    --exclude "$QUARANTINE" \
    --format '%w%f' \
    "${existing[@]}" \
    | while IFS= read -r path; do
      [[ -f $path ]] || continue
      log::info "New file: ${path}"
      "$SCANNER" "$path" || log::warn "Scan failed for ${path}"
    done
}

main "$@"
