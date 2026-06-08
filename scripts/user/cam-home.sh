#!/usr/bin/env bash
# Open RTSP camera streams from a DVR/NVR in mpv.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

DVR_URL_TEMPLATE="${DOTFILES_DVR_URL_TEMPLATE:?DOTFILES_DVR_URL_TEMPLATE must be set in local/env.sh}"

MPV_ARGS=(
  --profile=low-latency
  --no-cache
  --demuxer-lavf-o=rtsp_transport=tcp
  --no-audio
  --geometry=640x360
)

cam::usage() {
  cat << EOF
Usage: $(basename -- "$0") [CHANNEL...]

Open low-latency RTSP streams from the DVR in mpv, one window per camera.
With no arguments, opens DOTFILES_DVR_CHANNELS. Connection details come
from local/env.sh (DOTFILES_DVR_IP/USER/PASS/PORT/STREAM/CHANNELS, and
optionally DOTFILES_DVR_URL_TEMPLATE).
EOF
}

cam::require_env() {
  : "${DOTFILES_DVR_IP:?DOTFILES_DVR_IP not set in local/env.sh}"
  : "${DOTFILES_DVR_USER:?DOTFILES_DVR_USER not set in local/env.sh}"
  : "${DOTFILES_DVR_PASS:?DOTFILES_DVR_PASS not set in local/env.sh}"
  : "${DOTFILES_DVR_PORT:?DOTFILES_DVR_PORT not set in local/env.sh}"
  : "${DOTFILES_DVR_STREAM:?DOTFILES_DVR_STREAM not set in local/env.sh}"
  : "${DOTFILES_DVR_CHANNELS:?DOTFILES_DVR_CHANNELS not set in local/env.sh}"
}

cam::urlencode() {
  local s="$1" out="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) printf -v c '%%%02X' "'$c" && out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

cam::stream_url() {
  local channel="$1" stream_padded path
  stream_padded=$(printf '%02d' "$DOTFILES_DVR_STREAM")
  path="${DVR_URL_TEMPLATE/__CH__/$channel}"
  path="${path/__STREAM__/$stream_padded}"

  printf 'rtsp://%s:%s@%s:%s/%s' \
    "$(cam::urlencode "$DOTFILES_DVR_USER")" \
    "$(cam::urlencode "$DOTFILES_DVR_PASS")" \
    "$DOTFILES_DVR_IP" "$DOTFILES_DVR_PORT" "$path"
}

cam::open() {
  local channel="$1" url
  url=$(cam::stream_url "$channel")
  log::info "Opening Camera ${channel}..."
  mpv "${MPV_ARGS[@]}" "--title=Camera ${channel}" "$url" &
}

cam::main() {
  case "${1:-}" in
    -h | --help)
      cam::usage
      exit 0
      ;;
  esac

  os::check_dependency mpv || exit 1
  cam::require_env

  local channels=("$@")
  ((${#channels[@]})) || channels=("${DOTFILES_DVR_CHANNELS[@]}")

  local ch
  for ch in "${channels[@]}"; do
    cam::open "$ch"
  done

  log::info "Waiting for players to exit..."
  wait
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cam::main "$@"
fi
