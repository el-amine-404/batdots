#!/usr/bin/env bash
set -Eeuo pipefail

zenity::greet() {
  zenity --info \
    --width=360 \
    --title="dotfiles" \
    --text="Hello from dotfiles!

If you executed this,
then el-amine-404 loves you ❤️"
}

zenity::ensure_available() {
  command -v zenity > /dev/null 2>&1 || {
    notify-send "dotfiles" "zenity is not installed -- install it to see the greeting."
    return 1
  }
}

main() {
  zenity::ensure_available || exit 1
  zenity::greet
}

main "$@"
