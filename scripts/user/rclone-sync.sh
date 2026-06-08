#!/usr/bin/env bash
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"
# scripts/user/rclone-sync.sh -- sync a local directory to an rclone remote.
set -Eeuo pipefail

# shellcheck source=/dev/null

: "${RCLONE_SYNC_SRC:?RCLONE_SYNC_SRC is required}"
: "${RCLONE_SYNC_DEST:?RCLONE_SYNC_DEST is required}"
RCLONE_SYNC_LOG="${RCLONE_SYNC_LOG:-$HOME/.config/rclone/rclone.log}"

dir::create "$(dirname -- "$RCLONE_SYNC_LOG")"

args=(
  sync "$RCLONE_SYNC_SRC" "$RCLONE_SYNC_DEST"
  --log-file "$RCLONE_SYNC_LOG"
  --progress
  --drive-use-trash=false
  --create-empty-src-dirs
  --exclude "{node_modules/**,.git/**,.idea/**,.vscode/**,target/**,.angular/**,*.gitignore}"
)
[[ -n ${RCLONE_SYNC_DRY:-} ]] && args+=(--dry-run)

log::info "Starting rclone sync: $RCLONE_SYNC_SRC -> $RCLONE_SYNC_DEST"
exec rclone "${args[@]}"
