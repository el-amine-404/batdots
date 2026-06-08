#!/usr/bin/env bash
# yt-dlp -- Video downloader. Installs official binary to /usr/local/bin.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "install-yt-dlp"

# 1. Pre-Flight Checks
if ! command -v python3 &> /dev/null; then
  log::error "Python 3 is required but not found."
  exit 1
fi

# 2. Resolve Version (Centralized)
VERSION=$(build::resolve_version "YTDLP")

# 3. Idempotency Check (Standardized)
build::binary_already_installed "yt-dlp" "$VERSION" 'yt-dlp --version' && exit 0

# 4. Download & Install
DOWNLOAD_URL="https://github.com/yt-dlp/yt-dlp/releases/download/${VERSION}/yt-dlp"
TARGET_BIN="/usr/local/bin/yt-dlp"

TEMP_FILE=$(mktemp)

if http::download "$DOWNLOAD_URL" "$TEMP_FILE"; then
  log::info "Installing to $TARGET_BIN..."
  $SUDO_CMD mv "$TEMP_FILE" "$TARGET_BIN"
  $SUDO_CMD chmod a+rx "$TARGET_BIN"
  log::info "yt-dlp ${VERSION} installed successfully."
else
  log::error "Download failed for ${DOWNLOAD_URL}"
  rm -f "$TEMP_FILE"
  exit 1
fi

build::verify_binary "yt-dlp"
