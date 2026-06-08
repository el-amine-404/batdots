#!/usr/bin/env bash
# APT adapter (Debian, Ubuntu, Mint, Pop!_OS, Kali).

pkg_update() { $SUDO_CMD apt-get update -y; }
pkg_upgrade() { $SUDO_CMD apt-get upgrade -y; }
pkg_install() { $SUDO_CMD DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
pkg_clean() { $SUDO_CMD apt-get autoremove -y && $SUDO_CMD apt-get clean; }
