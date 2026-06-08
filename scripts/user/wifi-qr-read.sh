#!/usr/bin/env bash
# scripts/user/wifi-qr-read.sh -- Read WiFi QR code from camera.
set -Eeuo pipefail

# Sourcing logic
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

wqr::main() {
  os::check_dependency zbarcam || exit 1

  log::info "Starting zbarcam. Point your camera at a WiFi QR code."
  zbarcam
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  wqr::main "$@"
fi
