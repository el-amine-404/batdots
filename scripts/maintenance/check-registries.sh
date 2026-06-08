#!/usr/bin/env bash
# scripts/maintenance/check-registries.sh -- Verify every URL referenced by the
# repo's registry files is still reachable. Exits non-zero if any URL is dead,
# so it can gate CI / a scheduled job.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

declare -a CHECKREG_TARGETS=()
CHECKREG_OK=0
CHECKREG_DEAD=0

checkreg::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [REGISTRY_FILE ...]

Probe every http(s) URL found in the repo's pipe-delimited registry files
(apps/**/*.txt, config/**/*.txt). Plain URLs are fetched with curl; '*.git'
URLs are checked with 'git ls-remote'. Non-URL columns are ignored.

Options:
  -h, --help   Show this help message

With no REGISTRY_FILE, every registry under apps/ and config/ is scanned.
Exit status is non-zero when at least one URL is unreachable.
EOF
}

checkreg::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        checkreg::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        exit 1
        ;;
      *) CHECKREG_TARGETS+=("$1") ;;
    esac
    shift
  done
}

checkreg::all_registries() {
  find "${DOTFILES_ROOT}/apps" "${DOTFILES_ROOT}/config" -type f -name '*.txt' | sort
}

checkreg::resolve_targets() {
  ((${#CHECKREG_TARGETS[@]})) && return 0
  local file
  while IFS= read -r file; do CHECKREG_TARGETS+=("$file"); done < <(checkreg::all_registries)
}

checkreg::is_url() { [[ ${1:-} =~ ^https?:// ]]; }

checkreg::is_reachable() {
  local url="$1"
  if [[ $url == *.git ]]; then
    git ls-remote --exit-code -h "$url" > /dev/null 2>&1
  else
    curl -fsSL --retry 2 --max-time 25 -o /dev/null "$url" 2> /dev/null
  fi
}

checkreg::check_url() {
  local url="$1" origin="$2"
  if checkreg::is_reachable "$url"; then
    CHECKREG_OK=$((CHECKREG_OK + 1))
    log::debug "OK   $origin -> $url"
  else
    CHECKREG_DEAD=$((CHECKREG_DEAD + 1))
    log::error "DEAD $origin -> $url"
  fi
}

checkreg::check_file() {
  local file="$1"
  registry::require "$file" || return 0
  local origin="${file#"${DOTFILES_ROOT}/"}"
  local -a fields
  local value
  while IFS='|' read -ra fields; do
    for value in "${fields[@]}"; do
      checkreg::is_url "$value" && checkreg::check_url "$value" "$origin"
    done
  done < <(registry::stream "$file")
}

checkreg::check_all() {
  local target
  for target in "${CHECKREG_TARGETS[@]}"; do
    checkreg::check_file "$target"
  done
}

checkreg::report() {
  log::info "Checked -- ${CHECKREG_OK} reachable, ${CHECKREG_DEAD} dead."
  ((CHECKREG_DEAD == 0))
}

main() {
  checkreg::parse_args "$@"
  banner::print "registries"
  checkreg::resolve_targets
  checkreg::check_all
  checkreg::report
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
