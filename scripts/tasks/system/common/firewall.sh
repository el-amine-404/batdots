#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Host firewall for the homelab server (ufw): default-deny inbound, allow the
# Caddy gateway from anywhere, and the host-network services (AdGuard DNS,
# Netdata) only from the LAN. SSH is rate-limited, not opened wide.
#
# Note: Docker publishes ports via its own iptables chains and bypasses ufw, so
# this mainly guards SSH + host-network services. In batlab that's exactly the
# exposed surface (other service UIs are loopback-only or behind Caddy/Gluetun).
#
# Override via local/env.sh:
#   DOTFILES_HOMELAB_SSH_PORT   (default 22)
#   DOTFILES_HOMELAB_LAN_CIDRS  (space-separated; default RFC1918 ranges)

SSH_PORT="${DOTFILES_HOMELAB_SSH_PORT:-22}"

declare -a LAN_CIDRS
if [[ -n ${DOTFILES_HOMELAB_LAN_CIDRS:-} ]]; then
  read -ra LAN_CIDRS <<< "$DOTFILES_HOMELAB_LAN_CIDRS"
else
  LAN_CIDRS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16)
fi

# Reachable from anywhere -- the Caddy reverse-proxy gateway.
PUB_TCP_PORTS=(80 443)
PUB_UDP_PORTS=(443) # HTTP/3 (QUIC)
# Reachable from the LAN only -- host-network services.
LAN_TCP_PORTS=(53 3000 19999) # AdGuard DNS/TCP, AdGuard UI, Netdata
# 67 is the DHCP server port: when AdGuard serves DHCP, dropping it leaves every
# device on the LAN unable to get a lease.
LAN_UDP_PORTS=(53 67) # AdGuard DNS/UDP, AdGuard DHCP

fw::ufw() {
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] ufw $*"
    return 0
  fi
  $SUDO_CMD ufw "$@"
}

fw::ensure_installed() {
  if dpkg -s ufw > /dev/null 2>&1; then
    return 0
  fi
  log::info "Installing ufw..."
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] apt-get install -y ufw"
    return 0
  fi
  $SUDO_CMD env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw
}

fw::apply() {
  log::info "Applying firewall policy (default deny incoming)..."
  fw::ufw --force default deny incoming
  fw::ufw --force default allow outgoing

  # SSH first -- rate-limited and added BEFORE enabling to avoid lock-out.
  log::info "  Allowing SSH (rate-limited) on port ${SSH_PORT}..."
  fw::ufw limit "${SSH_PORT}/tcp" comment 'SSH (rate-limited)'

  log::info "  Allowing Caddy gateway (80/443) from anywhere..."
  local p
  for p in "${PUB_TCP_PORTS[@]}"; do
    fw::ufw allow "${p}/tcp" comment 'Caddy gateway'
  done
  for p in "${PUB_UDP_PORTS[@]}"; do
    fw::ufw allow "${p}/udp" comment 'Caddy HTTP/3'
  done

  log::info "  Allowing host-network services from LAN: ${LAN_CIDRS[*]}..."
  local cidr
  for cidr in "${LAN_CIDRS[@]}"; do
    for p in "${LAN_TCP_PORTS[@]}"; do
      fw::ufw allow from "$cidr" to any port "$p" proto tcp comment 'LAN service'
    done
    for p in "${LAN_UDP_PORTS[@]}"; do
      fw::ufw allow from "$cidr" to any port "$p" proto udp comment 'LAN service'
    done
  done
}

fw::enable() {
  log::info "Enabling ufw..."
  fw::ufw --force enable
  fw::ufw logging low
}

main() {
  banner::print "firewall"
  fw::ensure_installed
  fw::apply
  fw::enable
  log::info "Firewall configured. Review with: sudo ufw status verbose"
}

main "$@"
