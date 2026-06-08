#!/usr/bin/env bash
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"
# scripts/user/rofi-pdf.sh -- Rofi-based PDF selector and opener.
set -Eeuo pipefail

# shellcheck source=/dev/null

: "${DOTFILES_PDF_DIR:?DOTFILES_PDF_DIR not set in local/env.sh}"

[[ -d $DOTFILES_PDF_DIR ]] || {
  log::error "PDF directory not found: $DOTFILES_PDF_DIR"
  exit 1
}

SELECTED=$(find "$DOTFILES_PDF_DIR" -type f -iname "*.pdf" | sed "s|^$DOTFILES_PDF_DIR/||" | sort | rofi -dmenu -i -p "Choose PDF:")

[[ -z $SELECTED ]] && exit 0

TARGET_FILE="$DOTFILES_PDF_DIR/$SELECTED"

if file -b --mime-type "$TARGET_FILE" | grep -q "application/pdf"; then
  log::info "Opening $TARGET_FILE"
  nohup zathura "$TARGET_FILE" > /dev/null 2>&1 &
  disown
else
  log::error "Not a PDF: $TARGET_FILE"
  if command::exists notify-send; then
    notify-send "File Error" "NOT A PDF: $TARGET_FILE"
  fi
fi
