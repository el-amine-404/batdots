#!/usr/bin/env bash
# DNF adapter (Fedora, RHEL, Alma, Rocky, CentOS Stream).

pkg_update() { $SUDO_CMD dnf check-update || true; }
pkg_upgrade() { $SUDO_CMD dnf upgrade -y; }
pkg_install() { $SUDO_CMD dnf install -y "$@"; }
pkg_clean() { $SUDO_CMD dnf autoremove -y && $SUDO_CMD dnf clean all; }
