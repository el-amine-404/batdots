#!/usr/bin/env bash
# scripts/user/audio-record.sh -- Record a snippet and save it as an MP3.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

# Namespace: aur:: (AUdio Record)

aur::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [OUTPUT_FILE]

Options:
  -h, --help       Show this help message

Description:
  Records audio from the microphone and saves it as an MP3.
  If OUTPUT_FILE is not provided, it saves to DOTFILES_AUDIO_DIR.
  Press Ctrl+C to stop recording gracefully and view the summary.
EOF
}

aur::cleanup() {
  echo # Print newline after the ^C character
  if [[ -n "${OUTPUT_PATH:-}" ]] && [[ -f "$OUTPUT_PATH" ]]; then
    local size
    size=$(du -h "$OUTPUT_PATH" | cut -f1)
    log::info "Recording saved: $OUTPUT_PATH ($size)"
  else
    log::warn "Recording aborted or failed."
  fi
  exit 0
}

aur::main() {
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        aur::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        aur::usage
        exit 1
        ;;
      *) output="$1" ;;
    esac
    shift
  done

  os::check_dependency arecord lame || exit 1

  if [[ -z $output ]]; then
    : "${DOTFILES_AUDIO_DIR:?DOTFILES_AUDIO_DIR not set in local/env.sh}"
    dir::create "${DOTFILES_AUDIO_DIR}"
    local date
    date="$(date '+%Y-%b-%d_%Hh-%Mm-%Ss_%Z')"
    export OUTPUT_PATH="${DOTFILES_AUDIO_DIR}/audio_${date}.mp3"
  else
    export OUTPUT_PATH="$output"
    dir::create "$(dirname -- "$(readlink -f -- "$OUTPUT_PATH")")"
  fi

  log::info "Recording to $OUTPUT_PATH..."
  log::info "Press Ctrl+C to stop."

  # Trap SIGINT (Ctrl+C) to print the summary
  trap aur::cleanup INT

  local device="default"
  if arecord -L 2> /dev/null | grep -q "^pulse$"; then
    device="pulse"
  fi

  # arecord: -D <device> (uses active system mic), -q (quiet start), -V mono (VU meter on stderr)
  # lame: -r (raw pcm), -s 44.1 (sample rate matching --format=cd), --quiet (hide stats)
  if arecord -D "$device" -q -V mono --format=cd --file-type raw | lame --quiet -r -s 44.1 - "$OUTPUT_PATH"; then
    # If it ends naturally (e.g. somehow), still show summary
    aur::cleanup
  else
    # The pipeline will likely exit with 130 on SIGINT, trap handles it,
    # but if it fails for another reason, we handle it here.
    log::error "Recording process failed."
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  aur::main "$@"
fi
