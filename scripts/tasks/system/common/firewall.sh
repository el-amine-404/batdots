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
LAN_UDP_PORTS=(53)            # AdGuard DNS/UDP
# DHCP cannot be source-filtered: a client without a lease sends from 0.0.0.0 to
# the 255.255.255.255 broadcast, so a "from <lan cidr>" rule never matches it.
# It has to be allowed unscoped or every device fails to get an address.
BROADCAST_UDP_PORTS=(67) # AdGuard DHCP

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

  if ((${#BROADCAST_UDP_PORTS[@]})); then
    log::info "  Allowing broadcast services (DHCP) unscoped..."
    for p in "${BROADCAST_UDP_PORTS[@]}"; do
      fw::ufw allow "${p}/udp" comment 'Broadcast service (DHCP)'
    done
  fi

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

# ufw ships DEFAULT_FORWARD_POLICY="DROP", which sets the kernel FORWARD chain to
# DROP. Host traffic uses OUTPUT and is unaffected, but every Docker bridge
# network is forwarded -- so containers silently lose all egress the moment ufw
# is enabled. Container-level access control still belongs to Docker's
# DOCKER-USER chain; this only stops ufw from black-holing the whole bridge.
fw::allow_docker_forwarding() {
  local file="/etc/default/ufw"
  [[ -f $file ]] || return 0
  grep -q '^DEFAULT_FORWARD_POLICY="ACCEPT"' "$file" && {
    log::info "  Forward policy already ACCEPT (Docker bridges can reach the network)."
    return 0
  }
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would set DEFAULT_FORWARD_POLICY=\"ACCEPT\" in ${file}"
    return 0
  fi
  log::info "  Setting DEFAULT_FORWARD_POLICY=ACCEPT so Docker bridges keep egress..."
  $SUDO_CMD sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' "$file"
}

fw::enable() {
  fw::allow_docker_forwarding
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
