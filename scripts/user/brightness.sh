#!/usr/bin/env bash
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"
# scripts/user/brightness.sh -- Adjust and notify brightness changes.
set -Eeuo pipefail

STEP="${DOTFILES_BRIGHTNESS_STEP:?DOTFILES_BRIGHTNESS_STEP must be set in local/env.sh}"
NOTIFY_ID=9993

# Icon directory (required in local/env.sh)
ICON_DIR="${DOTFILES_ICON_DIR_BRIGHTNESS:?DOTFILES_ICON_DIR_BRIGHTNESS must be set in local/env.sh}"

get_current_brightness() {
  if ! command::exists brightnessctl; then
    echo "0"
    return
  fi
  brightnessctl -m | awk -F, '{print substr($4, 0, length($4)-1)}'
}

send_notification() {
  local val
  val=$(get_current_brightness)

  # Determine symbolic icon name
  local icon_name="brightness-high-symbolic"
  if ((val <= 45)); then
    icon_name="brightness-low-symbolic"
  elif ((val <= 75)); then
    icon_name="brightness-medium-symbolic"
  fi

  if command::exists dunstify; then
    dunstify -a "brightness" -u low -r "$NOTIFY_ID" -t 2000 -h int:value:"$val" -i "$icon_name" "Brightness" "${val}%"
  elif command::exists notify-send; then
    notify-send -a "brightness" -u low -t 2000 -i "$icon_name" -h int:value:"$val" -h string:x-canonical-private-synchronous:brightness "Brightness" "${val}%"
  fi
}

sanitize_percentage() {
  local input="${1:-}"

  if ! argument::is_int "$input"; then
    log::error "Invalid brightness value: '$input' (must be an integer)"
    return 1
  fi

  local val=$((input))

  if ((val < 0)); then
    echo 0
  elif ((val > 100)); then
    echo 100
  else
    echo "$val"
  fi
}
main() {
  command::exists brightnessctl || log::fatal "brightnessctl is not installed."

  case "${1:-}" in
    "up")
      brightnessctl set "+${STEP}%"
      send_notification
      ;;
    "down")
      brightnessctl set "${STEP}%-"
      send_notification
      ;;
    "set")
      local target
      if ! target=$(sanitize_percentage "${2:-}"); then
        log::fatal "Aborting: invalid target value."
      fi
      brightnessctl set "${target}%"
      send_notification
      ;;
    "get")
      get_current_brightness
      ;;
    *)
      echo "Usage: $(basename "$0") {up|down|get|set <0-100>}"
      exit 1
      ;;
  esac
}

main "$@"
