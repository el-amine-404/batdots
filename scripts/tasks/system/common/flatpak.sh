#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# SYSTEM TASK: FLATPAK SETUP
# Installs Flatpak binary, ensures it is up-to-date, and configures Flathub.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

# 1. PRE-FLIGHT CHECK
# We need basic system tools to install packages if Flatpak is missing.
os::check_dependency "curl" "sudo"

# 2. INSTALLATION / UPDATE LOGIC
if ! command -v flatpak > /dev/null 2>&1; then
  log::info "Flatpak not found. Installing via native package manager..."
  build::install_system_package "flatpak"
fi

# 3. VERIFICATION
if ! command -v flatpak > /dev/null 2>&1; then
  log::fatal "Flatpak installation logic finished, but 'flatpak' command is missing."
fi

VERSION=$(flatpak --version)
log::debug "Flatpak available: $VERSION"

# 4. CONFIGURATION (Security & Repositories)
log::info "Configuring Flathub repository..."

# Add Flathub (The standard secure source)
# --if-not-exists: Idempotent (safe to run multiple times)
if $SUDO_CMD flatpak remote-add --if-not-exists flathub "$FLATHUB_URL"; then
  log::info "Flathub remote configured."
else
  log::fatal "Failed to add Flathub remote."
fi

# 5. POST-INSTALL SECURITY (Optional but Recommended)
# Ensure the background portal service is running (critical for sandboxing to work)
if command -v systemctl > /dev/null 2>&1; then
  # We don't exit on fail here, as some docker/chroot envs don't have systemd
  # This ensures the permission management system is active
  $SUDO_CMD systemctl enable --now flatpak-system-helper.service > /dev/null 2>&1 || true
fi

log::info "Flatpak Setup Complete."
