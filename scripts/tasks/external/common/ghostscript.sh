#!/usr/bin/env bash
# ghostscript -- High-performance PostScript and PDF interpreter.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-ghostscript"

# 1. Resolve Version
VERSION=$(build::resolve_version "GHOSTSCRIPT")

# 2. Idempotency Check
build::binary_already_installed "gs" "$VERSION" 'gs --version' && exit 0

# 3. Aggressive Cleanup of old versions
build::purge_system_package "ghostscript"
build::purge_system_package "libgs-dev"

# Ensure common library paths are clean before source install
$SUDO_CMD rm -rf /usr/local/share/ghostscript
$SUDO_CMD rm -rf /usr/share/ghostscript

# 4. Source Acquisition -- Ghostscript tags are packed (gs10070 for 10.07.0)
ASSET_NAME=$(source::resolve_asset_url "GHOSTSCRIPT" "$GHOSTSCRIPT_ASSET")
PACKED=$(source::gs_dotted_to_packed "$VERSION")
URL="https://github.com/${GHOSTSCRIPT_REPO}/releases/download/gs${PACKED}/${ASSET_NAME}"
src_dir=$(build::fetch_tarball "ghostscript" "$VERSION" "$URL")

# 5. Build & Install
(
  cd "$src_dir" || exit 1
  log::info "Configuring Ghostscript..."
  ./configure --prefix="/usr/local"
  log::info "Compiling Ghostscript..."
  make -j "$(build::nproc)"
  log::info "Installing..."
  $SUDO_CMD make install
)

# 6. System Integration
$SUDO_CMD ln -sf /usr/local/bin/gs /usr/local/bin/ghostscript
$SUDO_CMD ldconfig

build::verify_binary "gs"
build::verify_binary "ghostscript"
build::cleanup "ghostscript"
log::info "ghostscript ${VERSION} done"
