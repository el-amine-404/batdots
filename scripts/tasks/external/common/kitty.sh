#!/usr/bin/env bash
# kitty -- Modern, hackable, GPU-based terminal emulator.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "install-kitty"

# 1. Resolve Version
VERSION=$(build::resolve_version "KITTY")

# 2. Idempotency Check
KITTY_BIN="${HOME}/.local/kitty.app/bin/kitty"
INSTALLED_VERSION="none"
if [[ -f $KITTY_BIN ]]; then
  INSTALLED_VERSION=$("$KITTY_BIN" --version | awk '{print $2}')
fi

if [[ "v${INSTALLED_VERSION}" == "$VERSION" ]]; then
  log::info "Kitty is already at the latest version ($VERSION)."
  # Repair symlinks if needed
  [[ -L "${HOME}/.local/bin/kitty" ]] || ln -sf "$KITTY_BIN" "${HOME}/.local/bin/kitty"
  exit 0
fi

# 3. Install via official script
log::info "Downloading and installing Kitty ${VERSION}..."
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin \
  dest="${HOME}/.local" \
  launch=n

# 4. System Integration
log::info "Configuring system integration..."
mkdir -p "${HOME}/.local/bin" "${HOME}/.local/share/applications"

ln -sf "${HOME}/.local/kitty.app/bin/kitty" "${HOME}/.local/bin/kitty"
ln -sf "${HOME}/.local/kitty.app/bin/kitten" "${HOME}/.local/bin/kitten"

# Desktop file
cp "${HOME}/.local/kitty.app/share/applications/kitty.desktop" "${HOME}/.local/share/applications/kitty.desktop"
sed -i "s|Icon=kitty|Icon=${HOME}/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" "${HOME}/.local/share/applications/kitty.desktop"
sed -i "s|Exec=kitty|Exec=${HOME}/.local/bin/kitty|g" "${HOME}/.local/share/applications/kitty.desktop"

log::info "kitty ${VERSION} done"
