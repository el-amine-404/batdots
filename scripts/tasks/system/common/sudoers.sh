#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

sudoers::admin_group_for_distro() {
  case "${OS_ID:-}" in
    fedora | rhel | centos | rocky | almalinux) echo "wheel" ;;
    *) echo "sudo" ;;
  esac
}

sudoers::target_user() {
  echo "${SUDO_USER:-$USER}"
}

sudoers::ensure_group_exists() {
  local group="$1"
  if ! getent group "$group" > /dev/null 2>&1; then
    log::warn "Group '$group' does not exist on this system -- nothing to do."
    return 1
  fi
}

sudoers::is_already_member() {
  local user="$1" group="$2"
  id -nG "$user" | tr ' ' '\n' | grep -qx "$group"
}

sudoers::add_user_to_group() {
  local user="$1" group="$2"
  log::info "Adding user '$user' to admin group '$group'..."
  $SUDO_CMD usermod -aG "$group" "$user"
  log::warn "Membership added -- log out and back in (or reboot) before it takes effect."
}

main() {
  banner::print "sudoers"
  local group user
  group=$(sudoers::admin_group_for_distro)
  user=$(sudoers::target_user)
  sudoers::ensure_group_exists "$group" || exit 0
  if sudoers::is_already_member "$user" "$group"; then
    log::info "User '$user' is already in '$group' -- nothing to do."
    exit 0
  fi
  sudoers::add_user_to_group "$user" "$group"
}

main "$@"
