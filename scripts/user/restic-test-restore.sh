#!/usr/bin/env bash
# scripts/user/restic-test-restore.sh -- Prove the restore path actually works:
# restore one sentinel file from the latest snapshot of the first reachable repo
# into a temp dir and assert it comes back readable and non-empty. restic verifies
# content hashes while restoring, so a clean restore is real proof the repo
# decrypts and the data is intact. Idempotent; intended for a monthly systemd
# timer. A backup you've never restored is a hope, not a backup.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# A file guaranteed to be in the backup set and present on disk: local/env.sh
# lives under the backed-up local/ dir. Override only if you don't back up local/.
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

  restic cat config > /dev/null 2>&1 || {
    log::warn "Repo not initialized yet (no backups) -- skipping."
    return 0
  }
  [[ -e $TR_SENTINEL ]] || log::fatal "Sentinel path does not exist locally: $TR_SENTINEL"

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would restore '${TR_SENTINEL}' from latest snapshot and verify it"
    return 0
  fi

  local out
  out=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '${out}'" RETURN

  # dump reads, decrypts and content-hash-verifies the file straight out of the
  # repo -- a clean dump is proof the snapshot is intact and recoverable.
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
