#!/usr/bin/env bash
# Flatpak adapter. System-level operations need privileges.

pkg_setup() { $SUDO_CMD flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; }
pkg_update() { $SUDO_CMD flatpak update -y; }
pkg_install() { $SUDO_CMD flatpak install -y --noninteractive --or-update flathub "$@"; }
pkg_clean() { $SUDO_CMD flatpak uninstall --unused -y; }
