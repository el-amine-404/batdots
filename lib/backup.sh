#!/usr/bin/env bash
# restic backup helpers -- multi-repo snapshots, retention, integrity, restore.
#
# Side-effect-free: defines functions only. Callers provide the DOTFILES_RESTIC_*
# environment (see local/env.sh) and a repo URL per call. The same password file
# is shared across all repos.
#
# Threat model: restic snapshots are versioned + encrypted, so ransomware that
# encrypts the live files just produces a new snapshot -- earlier clean ones are
# intact and restorable. Keep at least one repo air-gapped (a USB stick plugged
# in only during backup) so a compromised host can't reach every copy.

backup::require_restic() {
  command::exists restic || log::fatal "restic is not installed (apt install restic, or run bootstrap)."
}

# backup::use_repo REPO -- point restic at REPO using the shared password file.
backup::use_repo() {
  export RESTIC_REPOSITORY="${1:?backup::use_repo requires a repo}"
  export RESTIC_PASSWORD_FILE="${DOTFILES_RESTIC_PASS_FILE:?DOTFILES_RESTIC_PASS_FILE must be set in local/env.sh}"
  [[ -r $RESTIC_PASSWORD_FILE ]] || log::fatal "restic password file not readable: $RESTIC_PASSWORD_FILE"
}

# backup::repo_reachable REPO -- for a local/USB path repo, confirm its volume is
# actually mounted (never write into a bare mountpoint on the root fs). Remote
# repos (rclone:/sftp:/rest:/b2:/s3:...) are assumed reachable; restic errors
# clearly if not.
backup::repo_reachable() {
  local repo="$1"
  [[ $repo == /* ]] || return 0
  local parent
  parent=$(dirname -- "$repo")
  [[ -d $parent ]] || return 1
  case "$parent" in
    /media/* | /mnt/* | /run/media/*)
      local mountpoint
      mountpoint=$(df --output=target "$parent" 2> /dev/null | tail -1)
      [[ -n $mountpoint && $mountpoint != / ]] || return 1
      ;;
  esac
  return 0
}

# backup::ensure_initialized -- init the current repo if it has no config yet.
backup::ensure_initialized() {
  restic cat config > /dev/null 2>&1 && return 0
  log::info "Initializing restic repo: ${RESTIC_REPOSITORY}"
  restic init
}

# backup::existing_paths PATHS... -- echo only the paths that exist. restic errors
# on a missing path and machines differ, so absent ones are skipped.
backup::existing_paths() {
  local path
  for path in "$@"; do
    [[ -e $path ]] && printf '%s\n' "$path"
  done
}

# backup::snapshot TAG EXCLUDE_FILE PATHS... -- create one snapshot.
backup::snapshot() {
  local tag="$1" exclude="$2"
  shift 2
  local args=(backup --tag "$tag")
  [[ -r $exclude ]] && args+=(--exclude-file "$exclude")
  args+=("$@")
  restic "${args[@]}"
}

# backup::prune -- apply the retention policy to the current repo.
backup::prune() {
  restic forget --prune \
    --keep-daily "${DOTFILES_RESTIC_KEEP_DAILY:-7}" \
    --keep-weekly "${DOTFILES_RESTIC_KEEP_WEEKLY:-4}" \
    --keep-monthly "${DOTFILES_RESTIC_KEEP_MONTHLY:-12}" \
    --keep-yearly "${DOTFILES_RESTIC_KEEP_YEARLY:-3}"
}

# backup::check [ARGS...] -- verify repository integrity (add --read-data for a
# full content verification; default checks structure + metadata only).
backup::check() {
  restic check "$@"
}

# backup::repos -- print the configured repos, one per line. Prefers the
# DOTFILES_RESTIC_REPOS array; falls back to the legacy single DOTFILES_RESTIC_REPO.
backup::repos() {
  if [[ -n ${DOTFILES_RESTIC_REPOS+x} ]]; then
    printf '%s\n' "${DOTFILES_RESTIC_REPOS[@]}"
  elif [[ -n ${DOTFILES_RESTIC_REPO:-} ]]; then
    printf '%s\n' "$DOTFILES_RESTIC_REPO"
  fi
}
