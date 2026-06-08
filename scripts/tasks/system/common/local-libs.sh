#!/usr/bin/env bash
# scripts/tasks/system/common/local-libs.sh
# One-time system task: register /usr/local/lib in ldconfig and add
# PKG_CONFIG_PATH to the system profile so all users find compiled libs.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

banner::print "local-libs"

# LDCONFIG
LDCONF="/etc/ld.so.conf.d/local.conf"
if [[ ! -f "$LDCONF" ]]; then
  log::info "Registering /usr/local/lib in ldconfig..."
  printf '/usr/local/lib\n/usr/local/lib64\n' | $SUDO_CMD tee "$LDCONF" > /dev/null
  $SUDO_CMD ldconfig
  log::info "ldconfig updated"
else
  log::info "ldconfig already configured -- skipping"
fi

# SYSTEM-WIDE PKG_CONFIG_PATH
PROFILE_D="/etc/profile.d/local-libs.sh"
if [[ ! -f "$PROFILE_D" ]]; then
  log::info "Writing ${PROFILE_D}..."
  $SUDO_CMD tee "$PROFILE_D" > /dev/null << 'EOF'
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
export PATH="/usr/local/bin:${PATH}"
EOF
  log::info "Profile written -- will apply on next login"
else
  log::info "${PROFILE_D} already exists -- skipping"
fi

log::info "local-libs done"
