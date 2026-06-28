#!/usr/bin/env bash
# restic backup helper functions.

backup::require_restic() {
  command::exists restic || log::fatal "restic is not installed (apt install restic, or run bootstrap)."
}

backup::use_repo() {
  export RESTIC_REPOSITORY="${1:?backup::use_repo requires a repo}"
  export RESTIC_PASSWORD_FILE="${DOTFILES_RESTIC_PASS_FILE:?DOTFILES_RESTIC_PASS_FILE must be set in local/env.sh}"
  [[ -r $RESTIC_PASSWORD_FILE ]] || log::fatal "restic password file not readable: $RESTIC_PASSWORD_FILE"
}

# Check if parent is a mounted USB/external volume (avoid writing to empty mountpoint on root FS)
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

backup::ensure_initialized() {
  local exit_code=0
  restic cat config > /dev/null 2>&1 || exit_code=$?
  if ((exit_code == 0)); then
    return 0
  elif ((exit_code == 10)); then # Exit code 10 indicates uninitialized repo
    log::info "Initializing restic repo: ${RESTIC_REPOSITORY}"
    restic init
  else
    log::error "Failed to open repository: ${RESTIC_REPOSITORY} (exit code ${exit_code})"
    restic cat config > /dev/null
  fi
}

backup::existing_paths() {
  local path
  for path in "$@"; do
    [[ -e $path ]] && printf '%s\n' "$path"
  done
}

backup::snapshot() {
  local tag="$1" exclude="$2"
  shift 2
  local args=(backup --tag "$tag")
  [[ -r $exclude ]] && args+=(--exclude-file "$exclude")
  args+=("$@")
  restic "${args[@]}"
}

backup::prune() {
  restic forget --prune \
    --keep-daily "${DOTFILES_RESTIC_KEEP_DAILY:-7}" \
    --keep-weekly "${DOTFILES_RESTIC_KEEP_WEEKLY:-4}" \
    --keep-monthly "${DOTFILES_RESTIC_KEEP_MONTHLY:-12}" \
    --keep-yearly "${DOTFILES_RESTIC_KEEP_YEARLY:-3}"
}

backup::check() {
  restic check "$@"
}

backup::repos() {
  if [[ -n ${DOTFILES_RESTIC_REPOS+x} ]]; then
    printf '%s\n' "${DOTFILES_RESTIC_REPOS[@]}"
  elif [[ -n ${DOTFILES_RESTIC_REPO:-} ]]; then
    printf '%s\n' "$DOTFILES_RESTIC_REPO"
  fi
}
