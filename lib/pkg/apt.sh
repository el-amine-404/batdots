#!/usr/bin/env bash
# APT adapter (Debian, Ubuntu, Mint, Pop!_OS, Kali).

pkg_update() { $SUDO_CMD apt-get update -y; }
pkg_upgrade() { $SUDO_CMD apt-get upgrade -y; }
pkg_install() { $SUDO_CMD DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
pkg_clean() { $SUDO_CMD apt-get autoremove -y && $SUDO_CMD apt-get clean; }

pkg_unavailable() {
  [[ $# -eq 0 ]] && return 0
  local out
  out=$(apt-get install -s -y -- "$@" 2>&1 || true)
  printf '%s\n' "$out" | sed -nE \
    -e "s/.*Unable to locate package ([^ ]+).*/\1/p" \
    -e "s/.*Package '?([^' ]+)'? has no installation candidate.*/\1/p"
}
