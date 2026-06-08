#!/usr/bin/env bash
# scripts/user/notes-assets.sh -- Watch the notes-assets dir and rename each newly
# arrived file to a timestamp, so pasted/dropped assets get unique sortable names.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

NOTES_WATCH_DIR="${DOTFILES_NOTES_ASSETS_DIR:?DOTFILES_NOTES_ASSETS_DIR must be set in local/env.sh}"

notes::require_deps() {
  os::check_dependency inotifywait || exit 1
  [[ -d $NOTES_WATCH_DIR ]] || log::fatal "Notes assets dir not found: $NOTES_WATCH_DIR"
}

# A file we already renamed -- guards against re-processing our own moved_to event.
notes::already_stamped() {
  [[ $(basename -- "$1") =~ ^[0-9]{4}_[0-9]{2}_[0-9]{2}T[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{3}(\..+)?$ ]]
}

notes::stamped_path() {
  local file="$1" ext stamp
  stamp=$(date +%Y_%m_%dT%H_%M_%S_%3N)
  ext="${file##*.}"
  if [[ $ext == "$file" ]]; then
    printf '%s/%s' "$(dirname -- "$file")" "$stamp"
  else
    printf '%s/%s.%s' "$(dirname -- "$file")" "$stamp" "$ext"
  fi
}

notes::handle() {
  local file="$1" new
  [[ -f $file ]] || return 0
  notes::already_stamped "$file" && return 0
  new=$(notes::stamped_path "$file")
  file::move "$file" "$new"
  log::info "Renamed $(basename -- "$file") -> $(basename -- "$new")"
}

notes::watch() {
  log::info "Watching $NOTES_WATCH_DIR for new assets..."
  # close_write = a file finished being written; moved_to = a file moved in.
  # Watching 'create' would fire on partial/incomplete files mid-download.
  local file
  inotifywait -q -m -r -e close_write -e moved_to --format '%w%f' "$NOTES_WATCH_DIR" \
    | while IFS= read -r file; do
      notes::handle "$file"
    done
}

main() {
  notes::require_deps
  banner::print "notes assets"
  notes::watch
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
