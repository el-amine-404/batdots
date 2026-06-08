#!/usr/bin/env bash
# scripts/user/rofi-wallpaper.sh -- Rofi-based wallpaper selector.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

rwallpaper::resolve_dir() {
  printf '%s' "${DOTFILES_WALLPAPER_DIR:?DOTFILES_WALLPAPER_DIR must be set in local/env.sh}"
}

rwallpaper::validate_dir() {
  local dir="$1"
  [[ -d $dir ]] && return 0
  if [[ -n ${DOTFILES_WALLPAPER_DIR:-} ]]; then
    log::fatal "DOTFILES_WALLPAPER_DIR is set to '$dir' but the directory does not exist."
  fi
  log::error "Wallpaper directory not found: $dir"
  exit 1
}

rwallpaper::list() {
  find "$1" -type f \( -iname \*.jpg -o -iname \*.jpeg -o -iname \*.png -o -iname \*.webp \) -print0 | sort -z
}

rwallpaper::build_menu() {
  local dir="$1" file rel display
  shift
  for file in "$@"; do
    rel="${file#"$dir"}"
    rel="${rel#/}"
    display="${rel//$'\n'/ }"
    printf '%s\0icon\x1f%s\n' "$display" "$file"
  done
}

rwallpaper::main() {
  local dir
  dir="$(rwallpaper::resolve_dir)"
  rwallpaper::validate_dir "$dir"

  local -a files
  mapfile -d '' -t files < <(rwallpaper::list "$dir")
  ((${#files[@]})) || {
    log::error "No wallpapers found in $dir"
    exit 1
  }

  log::info "Launching wallpaper selection from $dir..."

  local index
  index=$(rwallpaper::build_menu "$dir" "${files[@]}" | rofi -dmenu -i -format i -show-icons -p "🖼️ Wallpapers") || exit 0

  local target="${files[$index]}"
  log::info "Applying wallpaper: $target"
  "${DOTFILES_ROOT}/scripts/user/wallpaper-set.sh" "$target"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  rwallpaper::main "$@"
fi
