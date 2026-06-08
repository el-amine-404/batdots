#!/usr/bin/env bash
# Pacman adapter (Arch, Manjaro, EndeavourOS).

pkg_update() { $SUDO_CMD pacman -Sy; }
pkg_upgrade() { $SUDO_CMD pacman -Syu --noconfirm; }
pkg_install() { $SUDO_CMD pacman -S --needed --noconfirm "$@"; }
pkg_clean() { $SUDO_CMD pacman -Rns --noconfirm "$(pacman -Qdtq 2> /dev/null)" 2> /dev/null || true; }
