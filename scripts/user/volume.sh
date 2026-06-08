#!/usr/bin/env bash
# scripts/user/volume.sh -- Adjust and notify volume changes.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

STEP=5
MAX_VOL=100
NOTIFY_ID=9993
SOUND_FILE="/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"

vol::current() {
  pactl get-sink-volume @DEFAULT_SINK@ | awk -F '/' 'NR==1 { gsub(/[^0-9]/, "", $2); print $2 }'
}

vol::sink_muted() {
  pactl get-sink-mute @DEFAULT_SINK@ | awk '{ print $2 }'
}

vol::mic_muted() {
  pactl get-source-mute @DEFAULT_SOURCE@ | awk '{ print $2 }'
}

vol::usage() {
  log::error "Usage: $(basename "$0") {up|down|mute|mic-mute}"
  exit 1
}

vol::up() {
  pactl set-sink-mute @DEFAULT_SINK@ 0
  local cur
  cur=$(vol::current)
  if ((cur + STEP > MAX_VOL)); then
    pactl set-sink-volume @DEFAULT_SINK@ "${MAX_VOL}%"
  else
    pactl set-sink-volume @DEFAULT_SINK@ "+${STEP}%"
  fi
}

vol::down() {
  pactl set-sink-mute @DEFAULT_SINK@ 0
  pactl set-sink-volume @DEFAULT_SINK@ "-${STEP}%"
}

vol::mute() {
  pactl set-sink-mute @DEFAULT_SINK@ toggle
}

vol::mic_toggle() {
  pactl set-source-mute @DEFAULT_SOURCE@ toggle
}

vol::notify() {
  local title="$1" msg="$2" icon="$3" progress="$4"
  progress=$((progress < 0 ? 0 : (progress > 100 ? 100 : progress)))

  if command::exists dunstify; then
    dunstify -a volume -u low -r "$NOTIFY_ID" -h int:value:"$progress" -i "$icon" "$title" "$msg"
  elif command::exists notify-send; then
    notify-send -a volume -u low -r "$NOTIFY_ID" -h int:value:"$progress" -i "$icon" "$title" "$msg"
  fi

  if [[ -f $SOUND_FILE ]]; then
    paplay "$SOUND_FILE" &
  fi
}

vol::notify_volume() {
  local vol muted icon text
  vol=$(vol::current)
  muted=$(vol::sink_muted)

  if [[ $muted == yes || $vol -eq 0 ]]; then
    icon="audio-volume-muted"
    text="Muted"
  elif ((vol < 30)); then
    icon="audio-volume-low"
    text="${vol}%"
  elif ((vol < 70)); then
    icon="audio-volume-medium"
    text="${vol}%"
  else
    icon="audio-volume-high"
    text="${vol}%"
  fi

  vol::notify "Volume" "$text" "$icon" "$vol"
}

vol::notify_mic() {
  if [[ $(vol::mic_muted) == yes ]]; then
    vol::notify "Microphone" "Muted" "microphone-sensitivity-muted" 0
  else
    vol::notify "Microphone" "Active" "microphone-sensitivity-high" 100
  fi
}

vol::main() {
  local action="${1:-}"

  case "$action" in
    up) vol::up ;;
    down) vol::down ;;
    mute) vol::mute ;;
    mic-mute) vol::mic_toggle ;;
    *) vol::usage ;;
  esac

  if [[ $action == mic-mute ]]; then
    vol::notify_mic
  else
    vol::notify_volume
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vol::main "$@"
fi
