#!/usr/bin/env bash
# scripts/user/power-menu.sh -- Rofi power menu (lock / logout / suspend / reboot...).

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

PM_POWEROFF="  Power Off"
PM_REBOOT="  Restart"
PM_SUSPEND="  Suspend"
PM_HIBERNATE="  Hibernate"
PM_LOGOUT="󰍃  Log Out"
PM_LOCK="  Lock"
PM_THEME="${HOME}/.config/rofi/power.rasi"

pm::menu_items() {
  printf '%s\n' "$PM_LOCK" "$PM_LOGOUT" "$PM_SUSPEND"
  # Only offer hibernate when the system can actually do it (no swap = no hibernate).
  if systemctl can-hibernate > /dev/null 2>&1; then
    printf '%s\n' "$PM_HIBERNATE"
  fi
  printf '%s\n' "$PM_REBOOT" "$PM_POWEROFF"
}

pm::choose() {
  local args=(-dmenu -i -p "Power")
  [[ -f $PM_THEME ]] && args+=(-theme-str "@import \"${PM_THEME}\"")
  pm::menu_items | rofi "${args[@]}"
}

pm::logout() {
  if pgrep -x openbox > /dev/null; then
    openbox --exit
  elif pgrep -x bspwm > /dev/null; then
    bspc quit
  elif pgrep -x i3 > /dev/null; then
    i3-msg exit
  elif pgrep -x sway > /dev/null; then
    swaymsg exit
  else
    loginctl terminate-user "$USER"
  fi
}

pm::lock() {
  if command::exists betterlockscreen; then
    betterlockscreen -l
  elif command::exists i3lock; then
    i3lock -c 000000
  elif command::exists slock; then
    slock
  else
    loginctl lock-session
  fi
}

main() {
  os::check_dependency rofi || exit 1

  local chosen
  # rofi exits non-zero when dismissed with Escape -- treat that as "cancel".
  chosen=$(pm::choose) || chosen=""
  [[ -n $chosen ]] || exit 0

  case "$chosen" in
    "$PM_POWEROFF") systemctl poweroff ;;
    "$PM_REBOOT") systemctl reboot ;;
    "$PM_SUSPEND") systemctl suspend ;;
    "$PM_HIBERNATE") systemctl hibernate ;;
    "$PM_LOGOUT") pm::logout ;;
    "$PM_LOCK") pm::lock ;;
    *) log::warn "Unknown selection: $chosen" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
