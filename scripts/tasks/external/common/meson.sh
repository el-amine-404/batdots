#!/usr/bin/env bash
# meson -- Build system required by libdav1d, mpv, and others.
# Installs/upgrades to the latest version system-wide via pip3.
# This ensures it's available to all users (and sudo) with correct module paths.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "setup-meson"

MIN_VERSION="1.3.0"

log::info "Ensuring modern meson (>= ${MIN_VERSION})..."

# 1. Ensure pip3 is present
if ! command -v pip3 &> /dev/null; then
  # Resolve generic name to native package name
  native_pip=$(packages::resolve_name "lang_pip3" "$(packages::detect_native_package_manager)")
  build::install_system_package "$native_pip"
fi

# 2. Cleanup user-local installations that cause environment conflicts
if [[ -f "${HOME}/.local/bin/meson" ]]; then
  log::info "Removing conflicting user-local meson/ninja..."
  python3 -m pip uninstall -y meson ninja 2> /dev/null || true
  rm -f "${HOME}/.local/bin/meson" "${HOME}/.local/bin/ninja"
fi

# 3. Upgrade meson via pip3 (System-wide)
# Installing system-wide prevents "ModuleNotFoundError" when running meson/ninja under sudo.
log::info "Upgrading meson and ninja system-wide via pip3..."
$SUDO_CMD python3 -m pip install --upgrade meson ninja --break-system-packages 2> /dev/null \
  || $SUDO_CMD python3 -m pip install --upgrade meson ninja 2> /dev/null

# 4. Verification
# Force hashing of the PATH to find the new system binary
hash -r
if ! command -v meson &> /dev/null; then
  log::error "Failed to install meson."
  exit 1
fi

log::info "Meson $(meson --version) is now ready system-wide."
