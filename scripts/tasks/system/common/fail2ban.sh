#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Brute-force protection via fail2ban, with an sshd jail enabled. Reads the
# journal so it works regardless of rsyslog being installed.
#
# Override via local/env.sh:
#   DOTFILES_HOMELAB_SSH_PORT       (default 22)
#   DOTFILES_HOMELAB_F2B_BANTIME    (default 1h)
#   DOTFILES_HOMELAB_F2B_MAXRETRY   (default 5)

SSH_PORT="${DOTFILES_HOMELAB_SSH_PORT:-22}"
BANTIME="${DOTFILES_HOMELAB_F2B_BANTIME:-1h}"
FINDTIME="${DOTFILES_HOMELAB_F2B_FINDTIME:-10m}"
MAXRETRY="${DOTFILES_HOMELAB_F2B_MAXRETRY:-5}"

JAIL="/etc/fail2ban/jail.d/homelab.local"

f2b::ensure_installed() {
  if dpkg -s fail2ban > /dev/null 2>&1; then
    return 0
  fi
  log::info "Installing fail2ban..."
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] apt-get install -y fail2ban"
    return 0
  fi
  $SUDO_CMD env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban
}

f2b::desired() {
  cat << EOF
# Managed by batdots (homelab profile).
[DEFAULT]
bantime  = ${BANTIME}
findtime = ${FINDTIME}
maxretry = ${MAXRETRY}
backend  = systemd

[sshd]
enabled = true
port    = ${SSH_PORT}
EOF
}

f2b::enable() {
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would enable and restart fail2ban.service"
    return 0
  fi
  log::info "  Enabling and restarting fail2ban..."
  $SUDO_CMD systemctl enable fail2ban > /dev/null 2>&1 || true
  $SUDO_CMD systemctl restart fail2ban
}

main() {
  banner::print "fail2ban"
  f2b::ensure_installed

  local desired
  desired=$(f2b::desired)

  if [[ -f $JAIL ]] && [[ "$(cat "$JAIL")" == "$desired" ]]; then
    log::info "${JAIL} already up to date."
  else
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
      log::info "  [DRY RUN] Would write ${JAIL}"
    else
      log::info "  Writing ${JAIL}..."
      printf '%s\n' "$desired" | $SUDO_CMD tee "$JAIL" > /dev/null
      $SUDO_CMD chmod 0644 "$JAIL"
    fi
  fi

  f2b::enable
  log::info "fail2ban active. Check with: sudo fail2ban-client status sshd"
}

main "$@"
