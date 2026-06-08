#!/usr/bin/env bash
set -Eeuo pipefail

source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

log::info "System Hardening (Firejail)"

# 1. Check if Firejail is installed
if ! command -v firejail > /dev/null; then
  log::error "Firejail is not installed. Skipping hardening."
  exit 1
fi

os::check_dependency "firecfg"

log::info "Applying Firejail symlinks (firecfg)..."

# Clean first to remove stale links
$SUDO_CMD firecfg --clean

for profile in /etc/firejail/*.profile; do
  app=$(basename "$profile" .profile)

  if command -v "$app" > /dev/null 2>&1; then
    case "$app" in
      firefox | chromium | google-chrome | brave | opera | zathura | evince | okular | atril | mupdf | libreoffice)
        log::info "Sandboxing $app"
        $SUDO_CMD ln -sf /usr/bin/firejail "/usr/local/bin/$app"
        ;;
    esac
  fi
done

log::info "System Hardening Complete"
