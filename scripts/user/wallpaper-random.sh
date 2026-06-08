#!/usr/bin/env bash
# scripts/user/wallpaper-random.sh -- Set a random wallpaper from the collection.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

wprandom::resolve_dir() {
  printf '%s' "${DOTFILES_WALLPAPER_DIR:?DOTFILES_WALLPAPER_DIR must be set in local/env.sh}"
}

wprandom::validate_dir() {
  local dir="$1"
  [[ -d $dir ]] && return 0
  if [[ -n ${DOTFILES_WALLPAPER_DIR:-} ]]; then
    log::fatal "DOTFILES_WALLPAPER_DIR is set to '$dir' but the directory does not exist."
  fi
  log::error "Wallpaper directory not found: $dir"
  exit 1
}

wprandom::pick() {
  find "$1" -type f \( -iname \*.jpg -o -iname \*.jpeg -o -iname \*.png -o -iname \*.webp \) -print0 | shuf -z -n 1 | tr -d '\0'
}

wprandom::main() {
  local dir selected
  dir="$(wprandom::resolve_dir)"
  wprandom::validate_dir "$dir"

  selected="$(wprandom::pick "$dir")"
  [[ -n $selected ]] || {
    log::error "No wallpapers found in $dir"
    exit 1
  }

  "${DOTFILES_ROOT}/scripts/user/wallpaper-set.sh" "$selected"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  wprandom::main "$@"
fi
