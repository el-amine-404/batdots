#!/usr/bin/env bash
# scripts/user/popup-calendar.sh -- Status-bar clock: print the date, or with
# --popup show a yad calendar near the cursor (bound to the bar's clock click).

set -Eeuo pipefail

CAL_BAR_HEIGHT=22
CAL_BORDER=1
CAL_WIDTH=222
CAL_HEIGHT=193

cal::print_date() {
  date +"%a %d %H:%M"
}

cal::already_open() {
  [[ $(xdotool getwindowfocus getwindowname 2> /dev/null) == "yad-calendar" ]]
}

cal::clamp_x() {
  local cursor_x="$1" screen_w="$2"
  if ((cursor_x + CAL_WIDTH / 2 + CAL_BORDER > screen_w)); then
    echo $((screen_w - CAL_WIDTH - CAL_BORDER))
  elif ((cursor_x - CAL_WIDTH / 2 - CAL_BORDER < 0)); then
    echo "$CAL_BORDER"
  else
    echo $((cursor_x - CAL_WIDTH / 2))
  fi
}

cal::clamp_y() {
  local cursor_y="$1" screen_h="$2"
  if ((cursor_y > screen_h / 2)); then
    echo $((screen_h - CAL_HEIGHT - CAL_BAR_HEIGHT - CAL_BORDER))
  else
    echo $((CAL_BAR_HEIGHT + CAL_BORDER))
  fi
}

cal::popup() {
  # Source the library only on the popup path -- the date path is polled by the
  # bar and needs nothing but coreutils, so keep it free of the full lib load.
  local root="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
  # shellcheck source=/dev/null
  source "${root}/lib/bash-utilities.sh"

  os::check_dependency yad xdotool || exit 1
  cal::already_open && exit 0

  local mouse geom cursor_x cursor_y screen_w screen_h pos_x pos_y
  mouse=$(xdotool getmouselocation --shell)
  cursor_x=$(sed -n 's/^X=//p' <<< "$mouse")
  cursor_y=$(sed -n 's/^Y=//p' <<< "$mouse")
  geom=$(xdotool getdisplaygeometry --shell)
  screen_w=$(sed -n 's/^WIDTH=//p' <<< "$geom")
  screen_h=$(sed -n 's/^HEIGHT=//p' <<< "$geom")

  pos_x=$(cal::clamp_x "$cursor_x" "$screen_w")
  pos_y=$(cal::clamp_y "$cursor_y" "$screen_h")

  yad --calendar --undecorated --fixed --close-on-unfocus --no-buttons \
    --width="$CAL_WIDTH" --height="$CAL_HEIGHT" --posx="$pos_x" --posy="$pos_y" \
    --title="yad-calendar" --borders=0 > /dev/null &
}

main() {
  case "${1:-}" in
    --popup) cal::popup ;;
    *) cal::print_date ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
