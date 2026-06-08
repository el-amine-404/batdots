#!/usr/bin/env bash
# scripts/user/audio-play.sh -- Play audio files using the best available player.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

# Namespace: aup:: (AUdio Play)

aup::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] <file|directory> ...

Options:
  -r, --recursive  Play files in directories recursively
  -s, --shuffle    Shuffle the playlist
  -h, --help       Show this help message

Description:
  Plays audio files using mpv, ffplay, or aplay (whichever is found first).
  Supports multiple files and directories. Files are sorted alphabetically
  by default.
EOF
}

aup::main() {
  local recursive=false
  local shuffle=false
  local targets=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --recursive) recursive=true ;;
      -s | --shuffle) shuffle=true ;;
      -h | --help)
        aup::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        aup::usage
        exit 1
        ;;
      *) targets+=("$1") ;;
    esac
    shift
  done

  if [[ ${#targets[@]} -eq 0 ]]; then
    aup::usage
    exit 2
  fi

  # Check for at least one player
  if ! command -v mpv > /dev/null && ! command -v ffplay > /dev/null && ! command -v aplay > /dev/null; then
    log::fatal "No audio player found. Please install mpv, ffmpeg, or alsa-utils."
  fi

  # 1. Gather all potential files
  local potential_files=()
  local target
  for target in "${targets[@]}"; do
    if [[ -d $target ]]; then
      local find_cmd=(find "$target" -maxdepth 1 -type f)
      if [[ $recursive == "true" ]]; then
        find_cmd=(find "$target" -type f)
      fi

      while IFS= read -r -d '' file; do
        potential_files+=("$file")
      done < <("${find_cmd[@]}" -print0 | sort -z)
    elif [[ -f $target ]]; then
      potential_files+=("$target")
    else
      log::error "Path not found: $target"
    fi
  done

  local total=${#potential_files[@]}
  if [[ $total -eq 0 ]]; then
    log::error "No files found to check."
    exit 1
  fi

  # 2. Validate files with a live progress indicator
  local all_files=()
  local current=0
  for file in "${potential_files[@]}"; do
    ((current++)) || :
    # Live progress indicator using carriage return (\r) and clear to end of line (\033[K)
    printf "\r\033[K  [%d/%d] Validating: %s" "$current" "$total" "$(basename -- "$file")"

    # Suppress output to maintain clean progress bar
    if audio::is_real_audio "$file" > /dev/null 2>&1; then
      all_files+=("$file")
    fi
  done
  # Clear the progress line completely when done
  printf "\r\033[K"

  if [[ ${#all_files[@]} -eq 0 ]]; then
    log::error "No playable audio files found."
    exit 1
  fi

  if [[ $shuffle == "true" ]]; then
    log::info "Shuffling playlist..."
    # Simple shuffle logic for Bash arrays
    local i j tmp
    for ((i = ${#all_files[@]} - 1; i > 0; i--)); do
      j=$((RANDOM % (i + 1)))
      tmp="${all_files[i]}"
      all_files[i]="${all_files[j]}"
      all_files[j]="$tmp"
    done
  fi

  audio::play "${all_files[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  aup::main "$@"
fi
