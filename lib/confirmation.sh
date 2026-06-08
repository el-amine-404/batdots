#!/usr/bin/env bash
# Tiny y/n confirmation helpers.
#
# Usage:
#   confirmation::seek "Proceed?"
#   confirmation::is_confirmed && echo yes

confirmation::seek() {
  printf '\n%s%s%s' "$BOLD" "$*" "$RESET"
  read -rp ' (y/n) ' -n 1
  printf '\n'
}

confirmation::seek_underline() {
  printf '\n%s%s%s' "$BOLD$UNDERLINE" "$*" "$RESET"
  read -rp ' (y/n) ' -n 1
  printf '\n'
}

confirmation::is_confirmed() {
  [[ $REPLY =~ ^[Yy]$ ]]
}
