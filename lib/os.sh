#!/usr/bin/env bash
# Identify the running distro from /etc/os-release (preferred) or /etc/lsb-release.
# Falls back to lowercased `uname` for non-Linux systems (mac, freebsd).
os::get_distribution_id() {
  local value
  if value=$(file::get_config_value /etc/os-release ID); then
    printf '%s' "$value"
    return 0
  fi
  if value=$(file::get_config_value /etc/lsb-release DISTRIB_ID); then
    printf '%s' "$value"
    return 0
  fi
  if value=$(uname 2> /dev/null); then
    printf '%s' "${value,,}"
    return 0
  fi
  return 1
}

os::get_distribution_id_like() {
  file::get_config_value /etc/os-release ID_LIKE
}

# Pick sudo or doas, refresh the credential cache, and export SUDO_CMD for
# downstream scripts. Refuses to continue if no escalation tool exists.
os::detect_privilege_tool() {
  if [[ $EUID -eq 0 ]]; then
    log::warn "Running as root -- child commands will skip sudo escalation"
    export SUDO_CMD=""
    return 0
  fi

  if command -v sudo &> /dev/null; then
    export SUDO_CMD="sudo"
    if ! sudo -n -v &> /dev/null; then
      log::info "Sudo password required..."
      sudo -v || log::fatal "sudo authentication failed"
    fi
    return 0
  fi

  if command -v doas &> /dev/null; then
    export SUDO_CMD="doas"
    return 0
  fi

  log::fatal "Root privileges required but neither 'sudo' nor 'doas' is available"
}

os::get_architecture() {
  local arch
  arch=$(uname -m) || return 1
  case "$arch" in
    x86_64 | amd64) echo "x86_64" ;;
    aarch64 | arm64) echo "aarch64" ;;
    i?86) echo "x86" ;;
    *) echo "$arch" ;;
  esac
}

os::check_dependency() {
  local missing=() tool
  for tool in "$@"; do
    command -v "$tool" > /dev/null 2>&1 || missing+=("$tool")
  done
  if ((${#missing[@]} > 0)); then
    log::error "Missing required tool(s): ${missing[*]}"
    return 1
  fi
}

os::is_virtual_machine() {
  grep -q hypervisor /proc/cpuinfo 2> /dev/null && return 0

  local product="" vendor=""
  [[ -r /sys/class/dmi/id/product_name ]] && product=$(< /sys/class/dmi/id/product_name)
  [[ -r /sys/class/dmi/id/sys_vendor ]] && vendor=$(< /sys/class/dmi/id/sys_vendor)
  if [[ "${product,,} ${vendor,,}" =~ (virtualbox|vmware|qemu|kvm|xen|bochs|innotek|vbox|kubevirt|google|amazon|microsoft) ]]; then
    return 0
  fi

  if command -v systemd-detect-virt &> /dev/null; then
    [[ "$(systemd-detect-virt)" != "none" ]] && return 0
  fi

  return 1
}

os::get_desktop_environment() {
  local de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  de="${de^^}" # uppercase

  case "$de" in
    *GNOME*) echo "GNOME" ;;
    *CINNAMON*) echo "CINNAMON" ;;
    *XFCE*) echo "XFCE" ;;
    *MATE*) echo "MATE" ;;
    *KDE* | *PLASMA*) echo "KDE" ;;
    *LXDE*) echo "LXDE" ;;
    *LXQT*) echo "LXQT" ;;
    *DEEPIN*) echo "DEEPIN" ;;
    *PANTHEON*) echo "PANTHEON" ;;
    *)
      # Fallback for WMs or unknown DEs
      if [[ -n ${GNOME_DESKTOP_SESSION_ID:-} ]]; then
        echo "GNOME"
      elif [[ -n ${KDE_FULL_SESSION:-} ]]; then
        echo "KDE"
      else
        echo "UNKNOWN"
      fi
      ;;
  esac
}
