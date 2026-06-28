#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Install ClamAV and keep its signatures fresh. The media scanner uses the
# daemon (clamdscan) when it's up, and falls back to clamscan otherwise.

clamav::ensure_installed() {
  if dpkg -s clamav-daemon > /dev/null 2>&1 && dpkg -s clamav-freshclam > /dev/null 2>&1; then
    return 0
  fi
  log::info "Installing ClamAV (engine + daemon + freshclam)..."
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] apt-get install -y clamav clamav-daemon clamav-freshclam"
    return 0
  fi
  $SUDO_CMD env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq clamav clamav-daemon clamav-freshclam
}

clamav::enable() {
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would enable clamav-freshclam + clamav-daemon"
    return 0
  fi
  log::info "  Enabling signature updates (clamav-freshclam)..."
  $SUDO_CMD systemctl enable --now clamav-freshclam.service > /dev/null 2>&1 || true
  log::info "  Enabling on-demand scanner daemon (clamav-daemon)..."
  $SUDO_CMD systemctl enable clamav-daemon.service > /dev/null 2>&1 || true
  # The daemon refuses to start until the first signature DB is downloaded;
  # that's fine -- the scanner falls back to clamscan until then.
  $SUDO_CMD systemctl start clamav-daemon.service > /dev/null 2>&1 \
    || log::warn "clamav-daemon will start once the first signatures finish downloading."
}

main() {
  banner::print "clamav"
  clamav::ensure_installed
  clamav::enable
  log::info "ClamAV ready. First signature download can take a few minutes."
}

main "$@"
