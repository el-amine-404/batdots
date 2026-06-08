#!/usr/bin/env bash
# scripts/user/restic-check.sh -- Verify the integrity of every reachable repo in
# DOTFILES_RESTIC_REPOS. Always checks structure + metadata; additionally re-reads
# a rotating fraction of the actual pack data (DOTFILES_RESTIC_CHECK_SUBSET,
# default 1/7) so the whole repo's bytes get re-verified for bit-rot over the
# rotation period. Idempotent; intended for a weekly systemd timer.
# A backup you never verify is a hope, not a backup.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

RC_SUBSET="${DOTFILES_RESTIC_CHECK_SUBSET:-1/7}"

RC_OK=0
RC_SKIPPED=0
RC_FAILED=0

rc::require_env() {
  local repos=()
  mapfile -t repos < <(backup::repos)
  ((${#repos[@]})) || log::fatal "No repos -- set DOTFILES_RESTIC_REPOS (array) in local/env.sh"
}

# Returns 0 on a clean check, 2 when the repo has no backups yet (skip), 1 on a
# real integrity failure.
rc::check_repo() {
  local repo="$1"
  log::info "-> $repo"
  backup::use_repo "$repo"

  if ! restic cat config > /dev/null 2>&1; then
    log::warn "Repo not initialized yet (no backups) -- skipping: $repo"
    return 2
  fi

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would run: restic check --read-data-subset=${RC_SUBSET}"
    return 0
  fi

  backup::check --read-data-subset="$RC_SUBSET"
}

rc::run_all() {
  local repo status
  while IFS= read -r repo; do
    if ! backup::repo_reachable "$repo"; then
      log::warn "Skipping unreachable repo (offline/unplugged): $repo"
      RC_SKIPPED=$((RC_SKIPPED + 1))
      continue
    fi
    status=0
    rc::check_repo "$repo" || status=$?
    case "$status" in
      0) RC_OK=$((RC_OK + 1)) ;;
      2) RC_SKIPPED=$((RC_SKIPPED + 1)) ;;
      *)
        log::error "Integrity check FAILED for repo: $repo"
        RC_FAILED=$((RC_FAILED + 1))
        ;;
    esac
  done < <(backup::repos)
}

rc::report() {
  local summary="restic check on $(hostname): ${RC_OK} ok, ${RC_SKIPPED} skipped, ${RC_FAILED} failed"
  log::info "$summary"
  # Only page on a real failure -- a clean check should be silent.
  [[ ${DRY_RUN:-0} == 1 ]] || ((RC_FAILED == 0)) \
    || notification::pushover "Backup integrity" "$summary" 2> /dev/null || true
  ((RC_FAILED == 0))
}

main() {
  banner::print "restic check"
  backup::require_restic
  rc::require_env
  rc::run_all
  rc::report
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
