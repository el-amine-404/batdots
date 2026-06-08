#!/usr/bin/env bash
# scripts/user/wallpaper-add.sh -- Add a new image to the wallpaper collection.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

wpadd::usage() {
  log::error "Usage: $(basename "$0") <file-or-url>"
  exit 1
}

wpadd::resolve_dir() {
  printf '%s' "${DOTFILES_WALLPAPER_DIR:?DOTFILES_WALLPAPER_DIR must be set in local/env.sh}"
}

wpadd::fetch() {
  local source="$1" target="$2"
  if [[ $source =~ ^https?:// ]]; then
    log::info "Downloading wallpaper: $source"
    curl -fsSL "$source" -o "$target"
  elif [[ -f $source ]]; then
    if [[ $(realpath -m "$source") != $(realpath -m "$target") ]]; then
      log::info "Copying wallpaper: $source"
      file::copy "$source" "$target"
    else
      log::info "File already in wallpaper directory: $source"
    fi
  else
    log::error "Invalid source: $source"
    exit 1
  fi
}

wpadd::main() {
  local source="${1:-}"
  [[ -n $source ]] || wpadd::usage

  local dir filename target
  dir="$(wpadd::resolve_dir)"
  dir::create "$dir"

  filename="$(basename "${source%%\?*}")"
  target="${dir}/${filename}"

  wpadd::fetch "$source" "$target"
  "${DOTFILES_ROOT}/scripts/user/wallpaper-set.sh" "$target"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  wpadd::main "$@"
fi
