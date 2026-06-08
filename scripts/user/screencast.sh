#!/usr/bin/env bash
# scripts/user/screencast.sh -- Toggle a screen-region recording with optional audio.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

CAST_DIR="${DOTFILES_SCREENCAST_DIR:?DOTFILES_SCREENCAST_DIR must be set in local/env.sh}"
CAST_PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-screencast.pid"
CAST_EXT="mp4"

declare -a CAST_AUDIO=()

cast::usage() {
  cat << EOF
Usage: $(basename "$0") [-d|-m]

Toggle a screen-region recording: run once to pick an area and start, run again
to stop. The MP4 finalizes cleanly and is saved to:
  $CAST_DIR

Options:
  -d   also capture desktop audio (default monitor)
  -m   also capture microphone (default source)
  -h   show this help
EOF
}

cast::notify() {
  command::exists notify-send && notify-send -a screencast -t 2000 "Screencast" "$1" || true
}

# Succeeds only if our pidfile points at a live ffmpeg we started.
cast::is_recording() {
  [[ -f $CAST_PIDFILE ]] || return 1
  local pid _rest
  read -r pid _rest < "$CAST_PIDFILE"
  [[ $pid =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2> /dev/null || return 1
  [[ $(cat "/proc/$pid/comm" 2> /dev/null) == ffmpeg ]]
}

cast::set_audio() {
  CAST_AUDIO=()
  case "${1:-}" in
    -d) CAST_AUDIO=(-f pulse -ac 2 -i @DEFAULT_MONITOR@) ;;
    -m) CAST_AUDIO=(-f pulse -ac 2 -i @DEFAULT_SOURCE@) ;;
  esac
}

cast::select_region() {
  local geom
  geom=$(slop -f "%x %y %w %h") || {
    log::info "Selection cancelled."
    exit 0
  }
  read -r X Y W H <<< "$geom"
  [[ -n ${W:-} && -n ${H:-} ]] || {
    log::info "Selection cancelled."
    exit 0
  }
  # libx264 requires even dimensions; trim a pixel where the selection is odd.
  W=$((W - W % 2))
  H=$((H - H % 2))
  ((W > 0 && H > 0)) || {
    log::warn "Selected region too small."
    exit 0
  }
}

cast::start() {
  os::check_dependency slop ffmpeg || exit 1
  cast::select_region
  cast::set_audio "${1:-}"
  dir::create "$CAST_DIR"

  local outfile="${CAST_DIR}/$(date '+%Y-%b-%d_%Hh-%Mm-%Ss_%Z').${CAST_EXT}"
  log::info "Recording ${W}x${H} at +${X},${Y} -> $outfile"

  # Only encode audio when an audio input was added, else ffmpeg warns that
  # -c:a/-b:a went unused.
  local -a acodec=()
  ((${#CAST_AUDIO[@]})) && acodec=(-c:a aac -b:a 128k)

  ffmpeg -nostdin -loglevel warning \
    -f x11grab -s "${W}x${H}" -framerate 60 -thread_queue_size 512 \
    -i "${DISPLAY}.0+${X},${Y}" \
    "${CAST_AUDIO[@]}" \
    "${acodec[@]}" -c:v libx264 -qp 18 -preset ultrafast \
    "$outfile" &

  printf '%s %s\n' "$!" "$outfile" > "$CAST_PIDFILE"
  cast::notify "Recording started"
}

cast::stop() {
  local pid path
  read -r pid path < "$CAST_PIDFILE"
  log::info "Stopping recording (pid $pid)..."
  # SIGINT lets ffmpeg write the MP4 moov atom -- SIGKILL would corrupt the file.
  kill -INT "$pid" 2> /dev/null || true
  rm -f -- "$CAST_PIDFILE"
  log::info "Stopped recording."
  cast::notify "Recording stopped${path:+ -- saved to $path}"
}

main() {
  case "${1:-}" in
    -h | --help)
      cast::usage
      exit 0
      ;;
  esac

  if cast::is_recording; then
    cast::stop
  else
    cast::start "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
