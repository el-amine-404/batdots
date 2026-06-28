#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Enable automatic security updates so the server self-patches CVEs.
#
# Override via local/env.sh:
#   DOTFILES_HOMELAB_AUTO_REBOOT       (default "false")
#   DOTFILES_HOMELAB_AUTO_REBOOT_TIME  (default "04:00")

AUTO_REBOOT="${DOTFILES_HOMELAB_AUTO_REBOOT:-false}"
AUTO_REBOOT_TIME="${DOTFILES_HOMELAB_AUTO_REBOOT_TIME:-04:00}"

PERIODIC_FILE="/etc/apt/apt.conf.d/20auto-upgrades"
POLICY_FILE="/etc/apt/apt.conf.d/52homelab-unattended-upgrades"

uu::ensure_installed() {
  if dpkg -s unattended-upgrades > /dev/null 2>&1; then
    return 0
  fi
  log::info "Installing unattended-upgrades..."
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] apt-get install -y unattended-upgrades apt-listchanges"
    return 0
  fi
  $SUDO_CMD env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades apt-listchanges
}

# Write $1 file with stdin content only if it differs (idempotent).
uu::write_file() {
  local path="$1" content="$2"
  if [[ -f $path ]] && [[ "$(cat "$path")" == "$content" ]]; then
    log::info "  ${path} already up to date."
    return 0
  fi
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would write ${path}"
    return 0
  fi
  log::info "  Writing ${path}..."
  printf '%s\n' "$content" | $SUDO_CMD tee "$path" > /dev/null
  $SUDO_CMD chmod 0644 "$path"
}

uu::configure() {
  uu::write_file "$PERIODIC_FILE" 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";'

  uu::write_file "$POLICY_FILE" "// Managed by batdots (homelab profile).
Unattended-Upgrade::Origins-Pattern {
    \"origin=Debian,codename=\${distro_codename},label=Debian-Security\";
    \"origin=Debian,codename=\${distro_codename}-security,label=Debian-Security\";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages \"true\";
Unattended-Upgrade::Remove-Unused-Dependencies \"true\";
Unattended-Upgrade::Automatic-Reboot \"${AUTO_REBOOT}\";
Unattended-Upgrade::Automatic-Reboot-Time \"${AUTO_REBOOT_TIME}\";"
}

uu::enable() {
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would enable unattended-upgrades.service + apt-daily timers"
    return 0
  fi
  log::info "  Enabling unattended-upgrades service and timers..."
  $SUDO_CMD systemctl enable --now unattended-upgrades.service > /dev/null 2>&1 || true
  $SUDO_CMD systemctl enable --now apt-daily.timer apt-daily-upgrade.timer > /dev/null 2>&1 || true
}

main() {
  banner::print "unattended-upgrades"
  uu::ensure_installed
  uu::configure
  uu::enable
  log::info "Automatic security updates enabled (auto-reboot=${AUTO_REBOOT})."
  log::info "Dry-run check: sudo unattended-upgrades --dry-run --debug"
}

main "$@"
