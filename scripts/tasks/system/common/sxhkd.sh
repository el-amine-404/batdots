#!/usr/bin/env bash
# Configures and manages sxhkd (Simple X Hotkey Daemon).
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

AUTOSTART_DIR="${HOME}/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

log::info "Configuring sxhkd..."

log::info "  Creating autostart entry..."
cat << EOF > "${AUTOSTART_DIR}/sxhkd.desktop"
[Desktop Entry]
Type=Application
Name=sxhkd
Comment=Simple X Hotkey Daemon
Exec=sh -c "pkill -x sxhkd; sxhkd"
Terminal=false
StartupNotify=false
Categories=System;Utility;
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
EOF
chmod 0644 "${AUTOSTART_DIR}/sxhkd.desktop"

if [[ -n ${DISPLAY:-} ]]; then
  log::info "  X session detected. Restarting sxhkd..."
  pkill -x sxhkd || true
  # Start in the home directory so children (terminals) inherit it
  (cd "$HOME" && nohup sxhkd > /dev/null 2>&1 &)
  log::info "  sxhkd restarted (PID: $(pgrep -x sxhkd))"
else
  log::info "  No X session detected. Skipping process restart."
fi
