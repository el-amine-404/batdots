#!/usr/bin/env bash
# DNF adapter (Fedora, RHEL, Alma, Rocky, CentOS Stream).

pkg_update() { $SUDO_CMD dnf check-update || true; }
pkg_upgrade() { $SUDO_CMD dnf upgrade -y; }
pkg_install() { $SUDO_CMD dnf install -y "$@"; }
pkg_clean() { $SUDO_CMD dnf autoremove -y && $SUDO_CMD dnf clean all; }

pkg_unavailable() {
  [[ $# -eq 0 ]] && return 0
  local out
  out=$($SUDO_CMD dnf install --assumeno -- "$@" 2>&1 || true)
  printf '%s\n' "$out" | sed -nE \
    -e "s/.*No match for argument: ([^ ]+).*/\1/p" \
    -e "s/.*Unable to find a match: ([^ ]+).*/\1/p"
}
