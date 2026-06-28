#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Harden the SSH server via a drop-in. Always disables root login and tightens
# auth; only disables PASSWORD auth when the target user already has an
# authorized key -- otherwise it would lock you out, so it warns and leaves
# password auth on until you install a key and re-run.

DROPIN="/etc/ssh/sshd_config.d/10-hardening.conf"

ssh::target_user() {
  echo "${SUDO_USER:-$USER}"
}

# True if the given user has at least one authorized_keys entry.
ssh::has_authorized_key() {
  local user="$1" home keyfile
  home=$(getent passwd "$user" | cut -d: -f6)
  keyfile="${home}/.ssh/authorized_keys"
  [[ -s $keyfile ]] && grep -qE '^(ssh-|ecdsa-|sk-)' "$keyfile" 2> /dev/null
}

ssh::ensure_installed() {
  if dpkg -s openssh-server > /dev/null 2>&1; then
    return 0
  fi
  log::info "Installing openssh-server..."
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] apt-get install -y openssh-server"
    return 0
  fi
  $SUDO_CMD env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server
}

ssh::build_config() {
  local disable_passwords="$1"
  cat << EOF
# Managed by batdots (homelab profile). See scripts/tasks/system/common/ssh-hardening.sh
PermitRootLogin no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
EOF
  if [[ $disable_passwords == 1 ]]; then
    echo "PubkeyAuthentication yes"
    echo "PasswordAuthentication no"
  else
    echo "# PasswordAuthentication left ON: no authorized_keys found for the admin"
    echo "# user. Install a key, then re-run this task to switch to key-only auth."
    echo "PasswordAuthentication yes"
  fi
}

main() {
  banner::print "ssh-hardening"
  ssh::ensure_installed

  local user disable_passwords=0
  user=$(ssh::target_user)
  if ssh::has_authorized_key "$user"; then
    disable_passwords=1
    log::info "Authorized key found for '${user}' -- enforcing key-only auth."
  else
    log::warn "No authorized_keys for '${user}'. Keeping password auth ON to avoid lock-out."
    log::warn "  Add a key (ssh-copy-id ${user}@<host>) and re-run to go key-only."
  fi

  local desired
  desired=$(ssh::build_config "$disable_passwords")

  if [[ -f $DROPIN ]] && [[ "$(cat "$DROPIN")" == "$desired" ]]; then
    log::info "${DROPIN} already up to date."
    exit 0
  fi

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would write ${DROPIN} and reload ssh (key-only=${disable_passwords})."
    exit 0
  fi

  log::info "  Writing ${DROPIN}..."
  $SUDO_CMD install -d -m 0755 /etc/ssh/sshd_config.d
  printf '%s\n' "$desired" | $SUDO_CMD tee "$DROPIN" > /dev/null
  $SUDO_CMD chmod 0644 "$DROPIN"

  log::info "  Validating sshd configuration..."
  if ! $SUDO_CMD sshd -t; then
    log::error "sshd config invalid -- removing drop-in and aborting."
    $SUDO_CMD rm -f "$DROPIN"
    exit 1
  fi

  log::info "  Reloading ssh (existing sessions stay connected)..."
  $SUDO_CMD systemctl reload ssh 2> /dev/null || $SUDO_CMD systemctl reload sshd
  log::info "SSH hardened (root login disabled, key-only=${disable_passwords})."
}

main "$@"
