#!/usr/bin/env bash
# scripts/user/catalog-bad-media.sh -- Catalog quarantined bad-media directories.
#
# The media validators (lib/{image,video,pdf}.sh) move corrupt files into
# BAD_JPG / BAD_PNG / BAD_VIDEO / BAD_PDF folders. This walks the tree and
# records where those folders are, into per-type logs under the trash dir, so
# you can review and purge them deliberately.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

cbm::catalog() {
  local trash="$1" found=1 dir name type log
  while IFS= read -r -d '' dir; do
    found=0
    name=$(basename -- "$dir")
    type="${name,,}"
    type="${type#bad_}"
    log="${trash}/bad_${type}.txt"
    realpath -- "$dir" >> "$log"
    log::warn "Found bad media: $dir (logged to $log)"
  done < <(find . -depth -type d \( -iname BAD_JPG -o -iname BAD_PNG -o -iname BAD_VIDEO -o -iname BAD_PDF \) -print0)
  return "$found"
}

cbm::main() {
  banner::print "cleaning"
  local trash="$HOME/.trash-scripts/BAD"
  dir::create "$trash"

  if cbm::catalog "$trash"; then
    log::warn "BAD media found. See logs in $trash"
  else
    log::info "No harmful media found."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cbm::main "$@"
fi
