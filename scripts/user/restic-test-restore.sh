#!/usr/bin/env bash
# Restic backup end-to-end restore verification.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Sentinel file to verify (must exist locally and in the backup)
TR_SENTINEL="${DOTFILES_RESTIC_TESTRESTORE_PATH:-${DOTFILES_ROOT}/local/env.sh}"

tr::first_reachable_repo() {
  local repo
  while IFS= read -r repo; do
    backup::repo_reachable "$repo" && {
      printf '%s' "$repo"
      return 0
    }
  done < <(backup::repos)
  return 1
}

tr::run() {
  local repo
  repo=$(tr::first_reachable_repo) || {
    log::warn "No reachable repo to test -- skipping."
    return 0
  }
  log::info "Test-restoring from: $repo"
  backup::use_repo "$repo"

  local exit_code=0
  restic cat config > /dev/null 2>&1 || exit_code=$?
  if ((exit_code == 10)); then
    log::warn "Repo not initialized yet (no backups) -- skipping."
    return 0
  elif ((exit_code != 0)); then
    log::error "Failed to open repository: $repo (exit code ${exit_code})"
    restic cat config > /dev/null
    return 1
  fi
  [[ -e $TR_SENTINEL ]] || log::fatal "Sentinel path does not exist locally: $TR_SENTINEL"

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would restore '${TR_SENTINEL}' from latest snapshot and verify it"
    return 0
  fi

  local out
  out=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '${out}'" RETURN

  restic dump latest "$TR_SENTINEL" > "$out" 2> /dev/null || return 1
  [[ -s $out ]] || {
    log::error "Restored sentinel is empty: $TR_SENTINEL"
    return 1
  }
  log::info "Verified restore of '${TR_SENTINEL}' ($(wc -c < "$out") bytes recovered from snapshot)"
}

main() {
  banner::print "restic test-restore"
  backup::require_restic

  local repos=()
  mapfile -t repos < <(backup::repos)
  ((${#repos[@]})) || log::fatal "No repos -- set DOTFILES_RESTIC_REPOS (array) in local/env.sh"

  local summary
  if tr::run; then
    summary="restic test-restore on $(hostname): OK"
    log::info "$summary"
    return 0
  fi
  summary="restic test-restore on $(hostname): FAILED"
  log::error "$summary"
  [[ ${DRY_RUN:-0} == 1 ]] || notification::pushover "Backup restore test" "$summary" 2> /dev/null || true
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
