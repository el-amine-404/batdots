#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

CONF_DIR="/etc/systemd/logind.conf.d"
CONF_FILE="${CONF_DIR}/10-laptop-server.conf"

lidsleep::should_configure() {
  if [[ ! -f "${CONF_FILE}" ]]; then
    return 0 # Needs config
  fi

  # Check if all handles are already set to ignore
  if ! grep -q "^HandleLidSwitch=ignore" "${CONF_FILE}" \
    || ! grep -q "^HandleLidSwitchExternalPower=ignore" "${CONF_FILE}" \
    || ! grep -q "^HandleLidSwitchDocked=ignore" "${CONF_FILE}"; then
    return 0 # Needs config
  fi

  return 1 # Already configured
}

lidsleep::configure() {
  log::info "Disabling suspend on lid close..."

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would create ${CONF_FILE} and configure systemd-logind to ignore lid close."
    return 0
  fi

  log::info "  Creating directory ${CONF_DIR}..."
  $SUDO_CMD mkdir -p "${CONF_DIR}"
  $SUDO_CMD install -d -m 0755 "${CONF_DIR}"

  log::info "  Writing ${CONF_FILE}..."
  $SUDO_CMD tee "${CONF_FILE}" > /dev/null << 'EOF'
[Login]
# Action when the lid closes in general
HandleLidSwitch=ignore
# Action when the lid closes while on AC power (overrides the general one)
HandleLidSwitchExternalPower=ignore
# Action when the lid closes while “docked” (external monitor/DOCK present)
# This overrides both above when applicable.
HandleLidSwitchDocked=ignore
EOF

  log::info "  Setting file permissions..."
  $SUDO_CMD chmod 0644 "${CONF_FILE}"

  log::info "  Reloading systemd-logind..."
  $SUDO_CMD systemctl reload-or-restart systemd-logind
}

main() {
  banner::print "disable-lid-sleep"

  if lidsleep::should_configure; then
    lidsleep::configure
  else
    log::info "Suspend on lid close is already disabled."
  fi
}

main "$@"
