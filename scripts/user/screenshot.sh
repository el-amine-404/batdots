#!/usr/bin/env bash
# scripts/user/screenshot.sh -- Capture screenshots, strip metadata, save or copy.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

SHOT_DIR="${DOTFILES_SCREENSHOT_DIR:?DOTFILES_SCREENSHOT_DIR must be set in local/env.sh}"
SHOT_TIMESTAMP="$(date '+%Y-%b-%d_%Hh-%Mm-%Ss_%Z')"
# scrot/gnome-screenshot write a fresh file; hand them a non-existent path inside
# a private dir (0700) rather than a pre-created file scrot would refuse to clobber.
SHOT_TMPDIR="$(mktemp -d --tmpdir "screenshot.XXXXXX")"
SHOT_TEMP="${SHOT_TMPDIR}/screenshot.png"
trap 'rm -rf -- "${SHOT_TMPDIR:-}"' EXIT

SHOT_MODE=""
SHOT_DEST=""

shot::usage() {
  cat << EOF
Usage: $(basename "$0") {save|copy}-{full-screen|selected-area|focused-window}

Capture a screenshot, strip its metadata, then either save it or copy it to
the clipboard.

  save-*   write a PNG to $SHOT_DIR
  copy-*   put the PNG on the clipboard (needs xclip)
  *-full-screen / *-selected-area / *-focused-window   what to capture
EOF
}

shot::parse_action() {
  local action="${1:-}"
  case "$action" in
    -h | --help)
      shot::usage
      exit 0
      ;;
  esac

  SHOT_DEST="${action%%-*}"
  case "$SHOT_DEST" in
    save | copy) ;;
    *)
      shot::usage >&2
      exit 1
      ;;
  esac

  case "${action#*-}" in
    full-screen) SHOT_MODE="full" ;;
    selected-area) SHOT_MODE="select" ;;
    focused-window) SHOT_MODE="window" ;;
    *)
      shot::usage >&2
      exit 1
      ;;
  esac
}

shot::require_tool() {
  command::exists scrot || command::exists gnome-screenshot \
    || log::fatal "No screenshot tool found -- install scrot or gnome-screenshot."
}

shot::capture() {
  if command::exists scrot; then
    case "$SHOT_MODE" in
      full) scrot "$SHOT_TEMP" ;;
      select) scrot --select --line mode=edge "$SHOT_TEMP" ;;
      window) scrot --focused "$SHOT_TEMP" ;;
    esac
  else
    case "$SHOT_MODE" in
      full) gnome-screenshot -f "$SHOT_TEMP" ;;
      select) gnome-screenshot -a -f "$SHOT_TEMP" ;;
      window) gnome-screenshot -w -f "$SHOT_TEMP" ;;
    esac
  fi
}

shot::strip_metadata() {
  if command::exists mogrify; then
    mogrify -strip "$SHOT_TEMP"
  elif command::exists exiftool; then
    exiftool -all= -overwrite_original "$SHOT_TEMP" > /dev/null 2>&1
  else
    log::warn "No metadata stripper (mogrify/exiftool) found -- keeping EXIF/metadata."
    return 1
  fi
  log::info "Stripped metadata."
}

shot::notify() {
  command::exists notify-send && notify-send -a screenshot -t 2000 "Screenshot" "$1" || true
}

shot::to_clipboard() {
  command::exists xclip || log::fatal "xclip not found -- cannot copy. File left at $SHOT_TEMP"
  xclip -selection clipboard -t image/png -i "$SHOT_TEMP"
  log::info "Screenshot copied to clipboard."
  shot::notify "Copied to clipboard"
}

shot::to_file() {
  dir::create "$SHOT_DIR"
  local final="${SHOT_DIR}/${SHOT_TIMESTAMP}.png"
  file::move "$SHOT_TEMP" "$final"
  log::info "Screenshot saved to $final"
  shot::notify "Saved to $final"
}

shot::deliver() {
  if [[ $SHOT_DEST == copy ]]; then
    shot::to_clipboard
  else
    shot::to_file
  fi
}

main() {
  shot::parse_action "${1:-}"
  shot::require_tool

  if ! shot::capture; then
    log::info "Capture cancelled -- nothing saved."
    exit 0
  fi
  [[ -s $SHOT_TEMP ]] || {
    log::info "No screenshot produced."
    exit 0
  }

  shot::strip_metadata || true
  shot::deliver
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
