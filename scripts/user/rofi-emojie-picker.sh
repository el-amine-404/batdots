#!/usr/bin/env bash
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"
# scripts/user/rofi-emojie-picker.sh -- Rofi-based emoji picker with clipboard support.
set -Eeuo pipefail

# shellcheck source=/dev/null

os::check_dependency rofi xclip curl || exit 1

URL="https://www.unicode.org/Public/emoji/latest/emoji-test.txt"
CACHE_DIR="${HOME}/.cache/rofi"
CACHE_FILE="${CACHE_DIR}/emoji.txt"
MAX_AGE_DAYS=30

dir::create "$CACHE_DIR"

update_cache() {
  log::info "Updating emoji cache..."
  if curl -sL --connect-timeout 10 "$URL" -o "${CACHE_FILE}.tmp"; then
    file::move "${CACHE_FILE}.tmp" "$CACHE_FILE"
    return 0
  else
    log::error "Emoji download failed."
    return 1
  fi
}

if [[ ! -f $CACHE_FILE ]]; then
  if command::exists notify-send; then
    notify-send "Emoji Picker" "Downloading emoji database..."
  fi
  update_cache || exit 1
else
  # Background update if old
  if [[ -n $(find "$CACHE_FILE" -mtime +$MAX_AGE_DAYS -print) ]]; then
    update_cache &
  fi
fi

# Extract emojis: look for fully-qualified lines, skip comments, take the part after #
OPTIONS=$(grep '; fully-qualified' "$CACHE_FILE" | awk -F'# ' '{print $2}')

if [[ -z $OPTIONS ]]; then
  log::error "Emoji database is empty or corrupt. Try deleting $CACHE_FILE"
  exit 1
fi

if ! SELECTED=$(echo "$OPTIONS" | rofi -dmenu -i -p "Emoji" -theme-str 'window {width: 30%;}'); then
  exit 0
fi

EMOJI=$(echo "$SELECTED" | awk '{print $1}')

if [[ -n $EMOJI ]]; then
  echo -n "$EMOJI" | xclip -selection clipboard
  log::info "Copied $EMOJI to clipboard"
  if command::exists notify-send; then
    notify-send -u low "Copied" "$EMOJI"
  fi
fi
