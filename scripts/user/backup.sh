#!/usr/bin/env bash
# scripts/user/backup.sh -- Timestamped tar.gz backup to DOTFILES_BACKUP_DIR.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

backup::usage() {
  cat << EOF
Usage: $(basename -- "$0")

Create a timestamped .tar.gz of DOTFILES_BACKUP_SOURCES into
DOTFILES_BACKUP_DIR, verify it, prune archives older than 7 days, and
notify via Pushover. Both variables are set in local/env.sh.
EOF
}

backup::require_env() {
  : "${DOTFILES_BACKUP_DIR:?DOTFILES_BACKUP_DIR not set in local/env.sh}"
  : "${DOTFILES_BACKUP_SOURCES:?DOTFILES_BACKUP_SOURCES not set in local/env.sh}"
}

# Refuse to write if the target lives on removable media that isn't mounted --
# otherwise tar silently fills the root filesystem at the bare mountpoint.
backup::require_mounted_target() {
  case "$DOTFILES_BACKUP_DIR" in
    /media/* | /mnt/* | /run/media/*)
      local mount_root
      mount_root=$(df --output=target "$(dirname -- "$DOTFILES_BACKUP_DIR")" 2> /dev/null | tail -1)
      [[ $mount_root == / || -z $mount_root ]] \
        && log::fatal "backup target ${DOTFILES_BACKUP_DIR} is not on a mounted volume"
      ;;
  esac
}

# Create the archive, then read it back to catch a truncated or corrupt write
# (e.g. the USB pulled mid-backup) before we trust it and prune older copies.
backup::create() {
  local archive="$1"
  tar -czpf "$archive" "${DOTFILES_BACKUP_SOURCES[@]}" \
    && tar -tzf "$archive" > /dev/null 2>&1
}

backup::prune() {
  find "$DOTFILES_BACKUP_DIR" -maxdepth 1 -type f -name '*.tar.gz' -mtime +7 -delete
}

backup::main() {
  case "${1:-}" in
    -h | --help)
      backup::usage
      exit 0
      ;;
  esac

  backup::require_env
  backup::require_mounted_target
  dir::create "$DOTFILES_BACKUP_DIR"

  local archive="${DOTFILES_BACKUP_DIR}/$(date '+%Y-%b-%d_%Hh-%Mm-%Ss_%Z').tar.gz"
  log::info "Backing up to ${archive}"

  if backup::create "$archive"; then
    backup::prune
    log::info "Backup completed successfully"
    notification::pushover "Backup" "Backup completed successfully on $(hostname)"
  else
    log::error "Backup failed"
    notification::pushover "Backup" "Backup FAILED on $(hostname)"
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  backup::main "$@"
fi
