#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Mount the media/download tree noexec,nosuid,nodev so that even an undetected
# malicious download physically cannot be executed from there. The data is on
# the root filesystem, so we use a self bind-mount made persistent via fstab.

DATA_ROOT="${DOTFILES_HOMELAB_DATA_ROOT:?DOTFILES_HOMELAB_DATA_ROOT must be set in local/env.sh}"
OPTS="bind,noexec,nosuid,nodev"
FSTAB="/etc/fstab"
FSTAB_LINE="${DATA_ROOT}  ${DATA_ROOT}  none  ${OPTS}  0  0"

mn::fstab_has_entry() {
  awk -v d="$DATA_ROOT" '!/^[[:space:]]*#/ && $2 == d && $4 ~ /noexec/ { found = 1 } END { exit !found }' "$FSTAB"
}

mn::is_hardened_now() {
  findmnt -no OPTIONS "$DATA_ROOT" 2> /dev/null | grep -q noexec
}

mn::add_fstab() {
  if mn::fstab_has_entry; then
    log::info "fstab already hardens ${DATA_ROOT}."
    return 0
  fi
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would append to ${FSTAB}: ${FSTAB_LINE}"
    return 0
  fi
  log::info "  Adding fstab entry for ${DATA_ROOT} (${OPTS})..."
  printf '\n# batdots: harden the media tree against execution\n%s\n' "$FSTAB_LINE" \
    | $SUDO_CMD tee -a "$FSTAB" > /dev/null
}

mn::apply_mount() {
  if mn::is_hardened_now; then
    log::info "${DATA_ROOT} is already mounted noexec."
    return 0
  fi
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would bind-mount and remount ${DATA_ROOT} with ${OPTS}"
    return 0
  fi
  log::info "  Applying ${OPTS} to ${DATA_ROOT} now..."
  if ! mountpoint -q "$DATA_ROOT"; then
    $SUDO_CMD mount --bind "$DATA_ROOT" "$DATA_ROOT"
  fi
  $SUDO_CMD mount -o "remount,${OPTS}" "$DATA_ROOT"
}

main() {
  banner::print "media noexec"
  if [[ ! -d $DATA_ROOT ]]; then
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
      log::info "  [DRY RUN] Would create ${DATA_ROOT}"
    else
      $SUDO_CMD mkdir -p "$DATA_ROOT"
    fi
  fi
  mn::add_fstab
  mn::apply_mount
  log::info "Media tree hardened. Verify with: findmnt ${DATA_ROOT}"
}

main "$@"
