#!/usr/bin/env bash
# Pacman adapter (Arch, Manjaro, EndeavourOS).

pkg_update() { $SUDO_CMD pacman -Sy; }
pkg_upgrade() { $SUDO_CMD pacman -Syu --noconfirm; }
pkg_install() { $SUDO_CMD pacman -S --needed --noconfirm "$@"; }
pkg_clean() { $SUDO_CMD pacman -Rns --noconfirm "$(pacman -Qdtq 2> /dev/null)" 2> /dev/null || true; }

pkg_unavailable() {
  [[ $# -eq 0 ]] && return 0
  local out
  out=$(pacman -Sp --print-format '%n' -- "$@" 2>&1 1> /dev/null || true)
  printf '%s\n' "$out" | sed -nE "s/.*target not found: ([^ ]+).*/\1/p"
}
