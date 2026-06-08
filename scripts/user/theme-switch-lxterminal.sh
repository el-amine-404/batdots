#!/usr/bin/env bash
# scripts/user/theme-switch-lxterminal.sh -- Switch LXTerminal color schemes.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

trap 'log::warn "Interrupted by user. Exiting..."; exit 130' SIGINT

LX_CONFIG_LINK="${DOTFILES_LXTERMINAL_CONFIG:?DOTFILES_LXTERMINAL_CONFIG must be set in local/env.sh}"
LX_THEME_DIR="${DOTFILES_LXTERMINAL_THEMES_DIR:?DOTFILES_LXTERMINAL_THEMES_DIR must be set in local/env.sh}"

LX_THEME_NAME=""
declare -a LX_SED_PROGRAM=()

lxterminal::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [THEME_NAME]

Switches LXTerminal colors based on theme files.

Options:
  -l, --list        List available themes
  -n, --dry-run     Show what would be changed without applying
  -u, --update      Show how themes are managed (via apps/themes/lxterminal.txt)
  -f, --force       Apply even while LXTerminal is running
  -h, --help        Show this help message

IMPORTANT: Close all LXTerminal windows before running this script.
EOF
}

lxterminal::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l | --list)
        lxterminal::list_themes
        exit 0
        ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -u | --update)
        lxterminal::show_management
        exit 0
        ;;
      -f | --force) export FORCE=1 ;;
      -h | --help)
        lxterminal::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        lxterminal::usage
        exit 1
        ;;
      *) LX_THEME_NAME="$1" ;;
    esac
    shift
  done
}

lxterminal::list_themes() {
  if [[ ! -d $LX_THEME_DIR ]]; then
    log::warn "Themes directory not found: $LX_THEME_DIR"
    return 1
  fi

  log::info "Available LXTerminal themes:"
  find -L "$LX_THEME_DIR" -maxdepth 1 -type f -name "*.conf" ! -name "lxterminal.conf" | sed 's|.*/||;s|\.conf$||' | sort | sed 's/^/  - /'
}

lxterminal::show_management() {
  local management_file="${DOTFILES_ROOT}/apps/themes/lxterminal.txt"
  log::info "LXTerminal themes are managed via: apps/themes/lxterminal.txt"
  if [[ -f $management_file ]]; then
    log::info "Configured sources:"
    registry::stream "$management_file" | sed 's/^/  /'
  fi
  log::info "To update themes, use: bin/packages.sh --task themes"
}

lxterminal::require_theme_name() {
  [[ -n $LX_THEME_NAME ]] && return 0
  log::error "No theme name provided."
  log::info "Run with --list to see available themes or --help for usage."
  exit 1
}

lxterminal::require_theme_files() {
  [[ -f "${LX_THEME_DIR}/${LX_THEME_NAME}.conf" ]] || {
    log::error "Theme '$LX_THEME_NAME' not found in $LX_THEME_DIR"
    lxterminal::list_themes
    exit 1
  }
  [[ -f $LX_CONFIG_LINK ]] || {
    log::error "LXTerminal config not found at $LX_CONFIG_LINK."
    exit 1
  }
}

lxterminal::abort_if_running() {
  pgrep -x "lxterminal" > /dev/null || return 0
  log::warn "LXTerminal is currently running."
  log::warn "Changes might be overwritten when LXTerminal closes."
  log::info "Please close ALL LXTerminal windows/tabs and try again."
  [[ ${FORCE:-0} == 1 ]] || exit 1
}

# Edit the symlink's target (the real file in the repo), not the link itself.
lxterminal::resolve_config_target() {
  readlink -f "$LX_CONFIG_LINK"
}

lxterminal::build_sed_program() {
  local target="$1" theme_file="$2"
  LX_SED_PROGRAM=()
  local key value
  while IFS='=' read -r key value || [[ -n $key ]]; do
    [[ $key =~ ^(bgcolor|fgcolor|palette_color_|color_preset|palette) ]] || continue
    value=$(string::trim "$value")
    if grep -q "^${key}=" "$target"; then
      LX_SED_PROGRAM+=("-e" "s|^${key}=.*|${key}=${value}|")
    else
      LX_SED_PROGRAM+=("-e" "/^\[general\]/a ${key}=${value}")
    fi
  done < "$theme_file"
}

lxterminal::apply() {
  local theme_file="${LX_THEME_DIR}/${LX_THEME_NAME}.conf"
  local target
  target=$(lxterminal::resolve_config_target)

  log::info "Applying theme '$LX_THEME_NAME' to $target"
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] Would update $target with colors from $LX_THEME_NAME"
    return 0
  fi

  lxterminal::build_sed_program "$target" "$theme_file"
  if ((${#LX_SED_PROGRAM[@]} == 0)); then
    log::warn "No valid theme keys found in $theme_file"
    return 0
  fi

  sed -i "${LX_SED_PROGRAM[@]}" "$target"
  log::info "Theme applied successfully to $target"
}

main() {
  lxterminal::parse_args "$@"
  lxterminal::require_theme_name
  banner::print "lx-theme"
  lxterminal::require_theme_files
  lxterminal::abort_if_running
  lxterminal::apply
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
