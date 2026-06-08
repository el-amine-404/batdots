#!/usr/bin/env bash
# scripts/user/prayer-times.sh -- Display today's Muslim prayer times.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

pt::usage() {
  cat << EOF
Usage: $(basename -- "$0") [OPTIONS]

Display today's Muslim prayer times for the resolved location. Caches
the response per-day per-backend so re-runs are free.

Options:
  -b, --backend NAME    Source to fetch from. One of: ${PRAYER_BACKENDS[*]}.
                        Default: aladhan (or \$DOTFILES_PRAYER_BACKEND).
  -C, --city NAME       Override city. Skips GeoIP detection.
      --country NAME    Override country.
  -c, --clear-cache     Delete today's cache and refetch.
  -h, --help            Show this help and exit.

Environment overrides (typically set in local/env.sh):
  DOTFILES_PRAYER_BACKEND     Default backend.
  DOTFILES_PRAYER_CITY        Default city (skips GeoIP).
  DOTFILES_PRAYER_COUNTRY     Default country.
  DOTFILES_PRAYER_METHOD      aladhan calculation method (1..15, default 3).
  DOTFILES_PRAYER_CITY_MAP    Habous override IDs: "city:id,city2:id2,...".
  DOTFILES_PRAYER_SCRAPE_URL  URL template for habous (must contain {ID}).

Fallback: if the requested backend fails, the script transparently
retries with aladhan before giving up.

Examples:
  $(basename -- "$0")                          # GeoIP + aladhan
  $(basename -- "$0") -b habous -C casablanca  # Habous backend, explicit city
  $(basename -- "$0") -c                       # Wipe today's cache, refetch
EOF
}

pt::parse_args() {
  PT_BACKEND=$(prayer::default_backend)
  PT_CITY=""
  PT_COUNTRY=""
  PT_CLEAR_CACHE=0

  while (($#)); do
    case "$1" in
      -b | --backend)
        PT_BACKEND="${2:?--backend requires a value}"
        shift 2
        ;;
      -C | --city)
        PT_CITY="${2:?--city requires a value}"
        shift 2
        ;;
      --country)
        PT_COUNTRY="${2:?--country requires a value}"
        shift 2
        ;;
      -c | --clear-cache)
        PT_CLEAR_CACHE=1
        shift
        ;;
      -h | --help)
        pt::usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        log::error "unknown argument: $1"
        pt::usage >&2
        exit 1
        ;;
    esac
  done
}

pt::resolve_missing_location() {
  [[ -n $PT_CITY && -n $PT_COUNTRY ]] && return 0
  local loc
  loc=$(prayer::resolve_location)
  [[ -z $PT_CITY ]] && PT_CITY="${loc%%|*}"
  [[ -z $PT_COUNTRY ]] && PT_COUNTRY="${loc##*|}"
}

pt::fetch_with_fallback() {
  if prayer::fetch "$PT_BACKEND" "$PT_CITY" "$PT_COUNTRY"; then
    return 0
  fi
  if [[ $PT_BACKEND != aladhan ]]; then
    log::warn "${PT_BACKEND} backend failed, falling back to aladhan"
    prayer::fetch aladhan "$PT_CITY" "$PT_COUNTRY" && return 0
  fi
  return 1
}

pt::main() {
  os::check_dependency jq curl || exit 1

  pt::parse_args "$@"
  prayer::is_known_backend "$PT_BACKEND" || {
    log::error "unknown backend '${PT_BACKEND}'. Known: ${PRAYER_BACKENDS[*]}"
    exit 1
  }

  prayer::cache_init
  ((PT_CLEAR_CACHE)) && {
    prayer::cache_clear
    log::info "cache cleared"
  }

  pt::resolve_missing_location

  local from_cache=false
  if prayer::cache_is_fresh "$PT_BACKEND" "$PT_CITY" "$PT_COUNTRY"; then
    from_cache=true
  elif ! pt::fetch_with_fallback; then
    log::fatal "all backends failed"
  fi

  prayer::render "$from_cache"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  pt::main "$@"
fi
