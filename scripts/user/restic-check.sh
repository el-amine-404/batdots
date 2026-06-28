#!/usr/bin/env bash
# Restic backup integrity checker.

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

rc::check_repo() {
  local repo="$1"
  log::info "-> $repo"
  backup::use_repo "$repo"

  local exit_code=0
  restic cat config > /dev/null 2>&1 || exit_code=$?
  if ((exit_code == 10)); then
    log::warn "Repo not initialized yet (no backups) -- skipping: $repo"
    return 2
  elif ((exit_code != 0)); then
    log::error "Failed to open repository: $repo (exit code ${exit_code})"
    restic cat config > /dev/null
    return 1
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
