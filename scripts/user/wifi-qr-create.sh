#!/usr/bin/env bash
# scripts/user/wifi-qr-create.sh -- Generate a WiFi QR code.
set -Eeuo pipefail

# Sourcing logic
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Global state for cleanup
WQC_TMPFILE=""

wqc::cleanup() {
  [[ -n "${WQC_TMPFILE:-}" ]] && rm -f "${WQC_TMPFILE}"
}

# Escape special characters for the WiFi QR format: \ ; , : "
wqc::escape() {
  local input="$1"
  # Order matters: escape backslashes first
  input="${input//\\/\\\\}"
  input="${input//;/\\;}"
  input="${input//,/\\,}"
  input="${input//:/\\:}"
  input="${input//\"/\\\"}"
  printf '%s' "$input"
}

wqc::main() {
  os::check_dependency qrencode feh dialog || exit 1

  WQC_TMPFILE=$(mktemp /tmp/wifi-qr-XXXXXX.png)
  trap wqc::cleanup EXIT INT TERM

  local ssid security password hidden

  ssid=$(dialog --title "SSID" --inputbox "Enter the SSID:" 8 40 3>&1 1>&2 2>&3) || exit 0
  security=$(dialog --title "SECURITY" --inputbox "Enter Security (WEP|WPA|blank):" 8 40 3>&1 1>&2 2>&3) || exit 0
  # SECURITY: Use --passwordbox to avoid leaking passwords on screen
  password=$(dialog --title "PASSWORD" --passwordbox "Enter Password:" 8 40 3>&1 1>&2 2>&3) || exit 0

  if dialog --yesno "Hidden network?" 8 40; then
    hidden="true"
  else
    hidden="false"
  fi

  # Escape inputs for the QR string
  local e_ssid e_password
  e_ssid=$(wqc::escape "$ssid")
  e_password=$(wqc::escape "$password")

  log::info "Generating QR code for ${ssid}..."
  qrencode "WIFI:S:${e_ssid};T:${security};P:${e_password};H:${hidden};;" -o "${WQC_TMPFILE}"

  log::info "Displaying QR code. Close the image viewer to finish."
  feh "${WQC_TMPFILE}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  wqc::main "$@"
fi
