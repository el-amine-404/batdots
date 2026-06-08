#!/usr/bin/env bash
# scripts/user/svg-logos.sh -- Download SVG logos declaratively from a registry.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

trap 'log::warn "Interrupted -- exiting."; exit 130' INT

LOGOS_REGISTRY="${DOTFILES_ROOT}/apps/logos/registry.txt"
LOGOS_DEST_DIR="${DOTFILES_SVG_LOGOS_DIR:?DOTFILES_SVG_LOGOS_DIR must be set in local/env.sh}"

LOGOS_FORCE=0
declare -a LOGOS_REQUESTED=()
declare -A LOGOS_MATCHED=()
LOGOS_DOWNLOADED=0
LOGOS_SKIPPED=0
LOGOS_FAILED=0

logos::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [LOGO_NAME ...]

Download SVG logos listed in the registry to your local logos directory.

Options:
  -l, --list      List every logo available in the registry
  -f, --force     Re-download even if the file already exists
  -n, --dry-run   Show what would happen without downloading
  -h, --help      Show this help message

With no LOGO_NAME, every logo in the registry is processed.

Registry:    $LOGOS_REGISTRY
Destination: $LOGOS_DEST_DIR
EOF
}

logos::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l | --list)
        logos::list
        exit 0
        ;;
      -f | --force) LOGOS_FORCE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        logos::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        log::info "Run with --help for usage."
        exit 1
        ;;
      *) LOGOS_REQUESTED+=("$1") ;;
    esac
    shift
  done
}

logos::list() {
  registry::require "$LOGOS_REGISTRY" || exit 1
  log::info "Available logos in $LOGOS_REGISTRY:"
  registry::field "$LOGOS_REGISTRY" 1 | sort | sed 's/^/  - /'
}

logos::is_selected() {
  local name="$1" requested
  ((${#LOGOS_REQUESTED[@]})) || return 0
  for requested in "${LOGOS_REQUESTED[@]}"; do
    if [[ $requested == "$name" ]]; then
      LOGOS_MATCHED[$name]=1
      return 0
    fi
  done
  return 1
}

# Reject HTML error pages saved with a 200 status -- only genuine SVG/XML passes.
logos::is_svg() {
  local head
  head=$(head -c 1024 -- "$1") || return 1
  grep -qiE '<svg|<\?xml' <<< "$head" || return 1
  ! grep -qiE '<!doctype html|<html[ >]' <<< "$head"
}

logos::download_one() {
  local name="$1" url="$2"
  local dest="${LOGOS_DEST_DIR}/${name}_logo.svg"

  if [[ -f $dest && $LOGOS_FORCE -ne 1 ]]; then
    log::debug "Exists, skipping: $name"
    LOGOS_SKIPPED=$((LOGOS_SKIPPED + 1))
    return 0
  fi

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would download $name ← $url"
    LOGOS_DOWNLOADED=$((LOGOS_DOWNLOADED + 1))
    return 0
  fi

  # Clear any prior file so curl's resume (-C -) can't no-op a forced refresh.
  rm -f -- "$dest"
  if ! http::download "$url" "$dest"; then
    LOGOS_FAILED=$((LOGOS_FAILED + 1))
    return 0
  fi

  if ! logos::is_svg "$dest"; then
    log::error "Not a valid SVG (server returned HTML/error?): $name ← $url"
    rm -f -- "$dest"
    LOGOS_FAILED=$((LOGOS_FAILED + 1))
    return 0
  fi

  LOGOS_DOWNLOADED=$((LOGOS_DOWNLOADED + 1))
}

logos::download_selected() {
  local name url
  while IFS='|' read -r name url; do
    logos::is_selected "$name" || continue
    logos::download_one "$name" "$url"
  done < <(registry::stream "$LOGOS_REGISTRY")
}

logos::warn_unmatched_requests() {
  ((${#LOGOS_REQUESTED[@]})) || return 0
  local requested
  for requested in "${LOGOS_REQUESTED[@]}"; do
    [[ -n ${LOGOS_MATCHED[$requested]:-} ]] || log::warn "Not in registry: $requested"
  done
  ((${#LOGOS_MATCHED[@]})) || log::fatal "None of the requested logos were found in the registry."
}

logos::report() {
  log::info "Done -- ${LOGOS_DOWNLOADED} downloaded, ${LOGOS_SKIPPED} skipped, ${LOGOS_FAILED} failed."
  ((LOGOS_FAILED == 0))
}

main() {
  logos::parse_args "$@"
  registry::require "$LOGOS_REGISTRY" || exit 1
  banner::print "logos"
  logos::download_selected
  logos::warn_unmatched_requests
  logos::report
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
