#!/usr/bin/env bash
# Open a local webcam stream using ffplay with MJPEG format.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

webcam::usage() {
  cat << EOF
Usage: $(basename "$0") [DEVICE] [TITLE]

Open a webcam stream using ffplay. Configuration can be overridden via:
  WEBCAM_TITLE, WEBCAM_FORMAT, WEBCAM_FRAMERATE, WEBCAM_SIZE
EOF
}

webcam::detect_device() {
  local preferred="${1:-/dev/video0}"
  if [[ -c "$preferred" && -r "$preferred" ]]; then
    printf '%s' "$preferred"
    return 0
  fi

  local device
  for device in /dev/video*; do
    [[ -e "$device" ]] || break
    [[ -c "$device" && -r "$device" ]] || continue
    printf '%s' "$device"
    return 0
  done

  return 1
}

webcam::open_stream() {
  local device="${1:?webcam device required}"
  local title="${2:-${WEBCAM_TITLE:-Webcam}}"
  local format="${WEBCAM_FORMAT:-mjpeg}"
  local rate="${WEBCAM_FRAMERATE:-30}"
  local size="${WEBCAM_SIZE:-1280x720}"

  log::info "Opening webcam stream: ${device}"
  exec ffplay \
    -f video4linux2 \
    -input_format "${format}" \
    -framerate "${rate}" \
    -video_size "${size}" \
    -window_title "${title}" \
    "${device}"
}

webcam::main() {
  case "${1:-}" in
    -h | --help)
      webcam::usage
      exit 0
      ;;
  esac

  os::check_dependency ffplay || exit 1

  local target_device
  target_device=$(webcam::detect_device "${1:-}") || {
    log::fatal "No accessible webcam device found."
  }

  webcam::open_stream "${target_device}" "${2:-}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  webcam::main "$@"
fi
