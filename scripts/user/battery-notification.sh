#!/usr/bin/env bash
# scripts/user/battery-notification.sh -- Notify once when battery goes low.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

BATTERY_LOW_THRESHOLD="${DOTFILES_BATTERY_LOW_THRESHOLD:?DOTFILES_BATTERY_LOW_THRESHOLD must be set in local/env.sh}"
BATTERY_STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/battery_notified"

battery::usage() {
  cat << EOF
Usage: $(basename -- "$0")

Notify (notify-send + Pushover) once when the battery drops to or below
DOTFILES_BATTERY_LOW_THRESHOLD (default 15) while discharging. Re-arms once
charged back above the threshold, so a timer won't spam notifications.
EOF
}

battery::device() {
  upower -e | grep -i 'BAT' | head -n1
}

# Echo "PERCENTAGE STATE" from a single upower call; percentage truncated to
# an integer (some upower versions report fractions, which break -le).
battery::read() {
  local dev="$1" info pct state
  info=$(upower -i "$dev") || return 1
  pct=$(awk '/percentage:/ {gsub(/%/,"",$2); print $2}' <<< "$info")
  state=$(awk '/state:/ {print $2}' <<< "$info")
  [[ -n $pct && -n $state ]] || return 1
  printf '%s %s' "${pct%.*}" "$state"
}

battery::notify_low() {
  local pct="$1"
  command::exists notify-send && notify-send -u critical "Battery Low" "Level: ${pct}%"
  notification::pushover "Battery Low" "Battery level on $(hostname) is ${pct}%"
}

battery::main() {
  case "${1:-}" in
    -h | --help)
      battery::usage
      exit 0
      ;;
  esac

  os::check_dependency upower || exit 1

  local dev
  dev=$(battery::device)
  [[ -n $dev ]] || {
    log::error "No battery found"
    exit 0
  }

  local reading pct state
  reading=$(battery::read "$dev") || {
    log::error "could not read battery status"
    exit 1
  }
  read -r pct state <<< "$reading"
  log::info "Battery: ${pct}% (${state})"

  if [[ $state == "discharging" && $pct -le $BATTERY_LOW_THRESHOLD ]]; then
    [[ -f $BATTERY_STATE_FILE ]] && return 0 # already alerted; stay quiet
    battery::notify_low "$pct"
    dir::ensure "$(dirname -- "$BATTERY_STATE_FILE")"
    : > "$BATTERY_STATE_FILE"
  else
    rm -f -- "$BATTERY_STATE_FILE" # re-arm for the next low event
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  battery::main "$@"
fi
