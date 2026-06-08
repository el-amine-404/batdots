#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

lightdm::ensure_installed() {
  if ! command -v lightdm > /dev/null 2>&1; then
    log::warn "lightdm is not installed -- install it via PACKAGES first."
    return 1
  fi
}

lightdm::enable_service_at_boot() {
  command -v systemctl > /dev/null 2>&1 || return 0
  if systemctl is-enabled lightdm.service > /dev/null 2>&1; then
    log::debug "lightdm.service is already enabled at boot."
    return 0
  fi
  log::info "Enabling lightdm.service so it starts at boot..."
  $SUDO_CMD systemctl enable lightdm.service
}

lightdm::set_as_default_display_manager() {
  [[ -f /etc/X11/default-display-manager ]] || return 0
  if grep -q '/usr/sbin/lightdm$' /etc/X11/default-display-manager; then
    log::debug "lightdm is already the default display manager."
    return 0
  fi
  log::info "Selecting lightdm as the system's default display manager..."
  echo "/usr/sbin/lightdm" | $SUDO_CMD tee /etc/X11/default-display-manager > /dev/null
}

lightdm::select_slick_greeter() {
  if ! command -v slick-greeter > /dev/null 2>&1 \
    && [[ ! -f /usr/share/xgreeters/lightdm-slick-greeter.desktop ]]; then
    log::warn "slick-greeter is not installed -- keeping the distro's default greeter."
    return 0
  fi
  local conf_dir="/etc/lightdm/lightdm.conf.d"
  local conf_file="${conf_dir}/60-slick-greeter.conf"
  local desired
  desired=$(
    cat << 'EOF'
[Seat:*]
greeter-session=lightdm-slick-greeter
EOF
  )
  if [[ -f $conf_file ]] && diff -q <(echo "$desired") "$conf_file" > /dev/null 2>&1; then
    log::debug "slick-greeter is already the configured greeter."
    return 0
  fi
  log::info "Setting slick-greeter as the LightDM greeter..."
  $SUDO_CMD mkdir -p "$conf_dir"
  echo "$desired" | $SUDO_CMD tee "$conf_file" > /dev/null
  $SUDO_CMD chmod 0644 "$conf_file"
}

lightdm::grant_greeter_home_access() {
  id -u lightdm > /dev/null 2>&1 || return 0
  if id -nG lightdm | tr ' ' '\n' | grep -qx "$USER"; then
    log::debug "The greeter already has read access to \$HOME."
    return 0
  fi
  log::info "Granting the greeter read access to \$HOME (so it can show your wallpaper)..."
  $SUDO_CMD usermod -aG "$USER" lightdm
}

main() {
  banner::print "lightdm"
  lightdm::ensure_installed || exit 0
  lightdm::enable_service_at_boot
  lightdm::set_as_default_display_manager
  lightdm::select_slick_greeter
  lightdm::grant_greeter_home_access
  log::info "LightDM setup complete."
}

main "$@"
