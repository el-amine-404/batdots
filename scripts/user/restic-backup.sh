#!/usr/bin/env bash
# scripts/user/restic-backup.sh -- Snapshot DOTFILES_RESTIC_BACKUP_PATHS into every
# repo in DOTFILES_RESTIC_REPOS (versioned, encrypted, deduplicated), then prune
# per the retention policy. Unreachable repos (e.g. the USB stick not plugged in)
# are skipped, not failed. Idempotent; intended for a nightly systemd timer.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

RB_TAG="${DOTFILES_RESTIC_BACKUP_TAG:-automated}"
RB_EXCLUDE="${DOTFILES_RESTIC_BACKUP_EXCLUDE:-${XDG_CONFIG_HOME:-$HOME/.config}/restic/restic_ignore}"

RB_OK=0
RB_SKIPPED=0
RB_FAILED=0

rb::require_env() {
  [[ -n ${DOTFILES_RESTIC_BACKUP_PATHS+x} ]] \
    || log::fatal "DOTFILES_RESTIC_BACKUP_PATHS (array) must be set in local/env.sh"
  local repos=()
  mapfile -t repos < <(backup::repos)
  ((${#repos[@]})) || log::fatal "No repos -- set DOTFILES_RESTIC_REPOS (array) in local/env.sh"
}

rb::backup_repo() {
  local repo="$1"
  log::info "-> $repo"
  backup::use_repo "$repo"
  backup::ensure_initialized

  local paths=()
  mapfile -t paths < <(backup::existing_paths "${DOTFILES_RESTIC_BACKUP_PATHS[@]}")
  ((${#paths[@]})) || {
    log::warn "None of the backup paths exist -- skipping $repo"
    return 0
  }

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would snapshot ${#paths[@]} path(s) -> $repo, then prune"
    return 0
  fi

  backup::snapshot "$RB_TAG" "$RB_EXCLUDE" "${paths[@]}" || return 1
  backup::prune || log::warn "prune failed on $repo (snapshot is safe)"
}

rb::run_all() {
  local repo
  while IFS= read -r repo; do
    if ! backup::repo_reachable "$repo"; then
      log::warn "Skipping unreachable repo (offline/unplugged): $repo"
      RB_SKIPPED=$((RB_SKIPPED + 1))
      continue
    fi
    if rb::backup_repo "$repo"; then
      RB_OK=$((RB_OK + 1))
    else
      log::error "Backup failed for repo: $repo"
      RB_FAILED=$((RB_FAILED + 1))
    fi
  done < <(backup::repos)
}

rb::report() {
  local summary="restic on $(hostname): ${RB_OK} ok, ${RB_SKIPPED} skipped, ${RB_FAILED} failed"
  log::info "$summary"
  [[ ${DRY_RUN:-0} == 1 ]] || notification::pushover "Backup" "$summary" 2> /dev/null || true
  ((RB_FAILED == 0))
}

main() {
  banner::print "restic backup"
  backup::require_restic
  rb::require_env
  rb::run_all
  rb::report
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
