#!/usr/bin/env bash
# scripts/user/wallpaper-set.sh -- Unified script to set the desktop wallpaper.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Path to the stable symlink that ensures .fehbg and DE settings remain valid after a repo rename.
STABLE_WP_PATH="${HOME}/.config/wallpaper-current"

wpset::usage() {
  log::error "Usage: $(basename "$0") <image-file>"
  exit 1
}

wpset::validate_image() {
  local target="$1" mime
  [[ -f $target ]] || wpset::usage
  mime=$(file -b --mime-type "$target")
  [[ $mime == image/* ]] || {
    log::error "File is not an image: $target ($mime)"
    exit 1
  }
}

wpset::apply() {
  local img="$1"
  local de
  de=$(os::get_desktop_environment)

  case "$de" in
    GNOME | CINNAMON | MATE)
      log::info "Setting $de wallpaper via gsettings..."
      gsettings set org.gnome.desktop.background picture-uri "file://${img}"
      gsettings set org.gnome.desktop.background picture-uri-dark "file://${img}"
      ;;
    XFCE)
      log::info "Setting XFCE wallpaper via xfconf..."
      local prop
      for prop in $(xfconf-query -c xfce4-desktop -p /backdrop -l | grep -E 'last-image$|image-path$'); do
        xfconf-query -c xfce4-desktop -p "$prop" -s "${img}"
      done
      ;;
    KDE)
      log::info "Setting KDE wallpaper via qdbus (experimental)..."
      local script="var allDesktops = desktops();
                    for (var i = 0; i < allDesktops.length; i++) {
                        allDesktops[i].wallpaperPlugin = 'org.kde.image';
                        allDesktops[i].currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
                        allDesktops[i].writeConfig('Image', 'file://${img}');
                    }"
      qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" > /dev/null 2>&1 \
        || log::warn "KDE wallpaper update failed. Ensure Plasma is running."
      ;;
    *)
      if command::exists feh; then
        log::info "Setting WM wallpaper via feh..."
        feh --bg-fill "${img}"
      else
        log::warn "Unknown environment and 'feh' not found. Wallpaper not set."
      fi
      ;;
  esac
}

wpset::notify() {
  command::exists notify-send || return 0
  notify-send -u low "Wallpaper Set" "$(basename "$1")"
}

wpset::remember() {
  local src
  src=$(readlink -f "$1")

  # Ensure target directory exists
  local wp_dir
  wp_dir=$(dirname "$STABLE_WP_PATH")
  [[ -d $wp_dir ]] || mkdir -p "$wp_dir"

  # Use a stable path for the actual wallpaper setting.
  # This makes .fehbg and DE configs survive a repository rename.
  ln -sfn "$src" "$STABLE_WP_PATH"
  # Also keep the old symlink for backward compatibility if any script expects it.
  ln -sfn "$src" "$HOME/.current_wallpaper"
}

wpset::main() {
  local target="${1:-}"
  [[ -n $target ]] || wpset::usage

  wpset::validate_image "$target"
  log::info "Processing wallpaper: $(basename "$target")"

  # 1. Update the stable symlink first
  wpset::remember "$target"

  # 2. Apply using the STABLE path
  wpset::apply "$STABLE_WP_PATH"

  # 3. Notify user
  wpset::notify "$target"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  wpset::main "$@"
fi
