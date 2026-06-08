#!/usr/bin/env bash

set -Eeuo pipefail

TRASH_DIR="${HOME}/.trash-sxiv"

# Example for $XDG_CONFIG_HOME/sxiv/exec/key-handler
# Called by sxiv(1) after the external prefix key (C-x by default) is pressed.
# The next key combo is passed as its first argument. Passed via stdin are the
# images to act upon, one path per line: all marked images, if in thumbnail
# mode and at least one image has been marked, otherwise the current image.
# sxiv(1) blocks until this script terminates. It then checks which images
# have been modified and reloads them.

# First you have to press Ctrl-x, then one of the following shortcuts
# make sure this file ix executable: .config/sxiv/exec/key-handler
# example script: https://github.com/xyb3rt/sxiv/blob/master/exec/key-handler
# --- Helpers ---
has() { command -v "$1" > /dev/null 2>&1; }

# Dynamically find ImageMagick command (fixes the /usr/bin/convert error)
if has magick; then
  IM_CONVERT="magick"
elif has convert; then
  IM_CONVERT="convert"
else
  IM_CONVERT=""
fi

notify() {
  local urgency="${2:-normal}"
  notify-send -t 2500 -i "image-viewer" -u "$urgency" "sxiv" "$1"
}

delete_to_trash() {
  mkdir -p "$TRASH_DIR"
  local count=0
  local fail=0
  while read -r file; do
    [[ -f $file ]] || continue
    if mv "$file" "$TRASH_DIR/"; then
      ((count++))
    else
      ((fail++))
    fi
  done

  if [[ $fail -gt 0 ]]; then
    notify "Success: $count | Failed: $fail (Check permissions)" "critical"
  else
    notify "Deleted $count image(s) to trash"
  fi
}

rotate_image() {
  local degree="$1"
  [[ -z $IM_CONVERT ]] && {
    notify "Error: ImageMagick not found!" "critical"
    return 1
  }

  local success=true
  while read -r file; do
    if ! "$IM_CONVERT" "$file" -rotate "$degree" "$file"; then
      success=false
      break
    fi
  done

  if $success; then
    notify "Rotated selected images $degree°"
  else
    notify "Rotation failed! File might be read-only." "critical"
  fi
}
set_wallpaper() {
  read -r file
  [[ -z $file || ! -f $file ]] && return

  # Use the centralized dotfiles script
  if "$HOME/.local/bin/dotfiles/wallpaper-set.sh" "$file"; then
    notify "Wallpaper set: $(basename "$file")"
  else
    notify "Failed to set wallpaper" "critical"
  fi
}

show_exif() {
  while read -r file; do
    # Terminal preference list: urxvt -> st -> xterm -> fallback
    if has urxvt; then
      urxvt -title "EXIF: $file" -e sh -c "exiftool '$file' | less" &
    elif has st; then
      st -T "EXIF: $file" -e sh -c "exiftool '$file' | less" &
    elif has xterm; then
      xterm -title "EXIF: $file" -e sh -c "exiftool '$file' | less" &
    else
      notify "Error: No terminal found to display EXIF" "critical"
    fi
  done
}

clipboard_image() {
  [[ -z $IM_CONVERT ]] && { notify "IM missing; copying raw data..." "low"; }

  local count=0
  while read -r file; do
    [[ -f $file ]] || continue
    mime_type=$(file -b --mime-type "$file")

    # Capture status of xclip
    if [[ $mime_type == "image/png" ]]; then
      xclip -selection clipboard -t image/png "$file" && ((count++))
    else
      "$IM_CONVERT" "$file" png:- | xclip -selection clipboard -t image/png && ((count++))
    fi
  done
  [[ $count -gt 0 ]] && notify "Copied $count image(s) to clipboard"
}

copy_path() {
  # tr '\n' ' ' removes the newline for easy pasting into terminal/code
  tr '\n' ' ' | xclip -selection clipboard
  notify "File path(s) copied to clipboard"
}

open_external() {
  local app="$1"
  if ! has "$app"; then
    notify "Error: $app not installed" "critical"
    return
  fi
  # Use -0 for safe filename handling, check if xargs succeeds
  if tr '\n' '\0' | xargs -0 "$app" > /dev/null 2>&1 & then
    notify "Opening in $app..."
  else
    notify "Failed to launch $app" "critical"
  fi
}

# --- Main Dispatcher ---
# Note: sxiv sends file paths via STDIN
case "${1:-}" in
  "d") delete_to_trash ;;
  "r") rotate_image 90 ;;
  "l") rotate_image 270 ;;
  "c") clipboard_image ;;
  "x") copy_path ;;
  "w") set_wallpaper ;;
  "e") show_exif ;;
  "g") open_external "gimp" ;;
  "y") open_external "rawtherapee" ;;
  *) notify "Key [$1] not recognized" "low" ;;
esac
