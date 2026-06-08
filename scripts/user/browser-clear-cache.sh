#!/usr/bin/env bash
# scripts/user/browser-clear-cache.sh -- Free disk space by clearing browser caches.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

: "${HOME:?HOME not set}"

# Force-killed before clearing -- unsaved tabs are lost. This trade-off is
# intentional: the caches can be locked while a browser is running.
BROWSER_PROCESSES=(firefox firefox-bin chrome chromium brave brave-browser)

bcc::usage() {
  cat << EOF
Usage: $(basename -- "$0")

Stop running browsers and delete their on-disk caches (native + snap
locations) to reclaim space. This clears only the performance cache -- it
does NOT touch cookies, history, or logins. Honors DRY_RUN=1.
EOF
}

# Cache directories purged when present. Performance cache only; profile data
# (cookies/history) lives elsewhere and is deliberately left alone.
bcc::cache_dirs() {
  printf '%s\n' \
    "$HOME/.cache/chromium" \
    "$HOME/.cache/google-chrome" \
    "$HOME/.cache/BraveSoftware" \
    "$HOME/.cache/mozilla" \
    "$HOME/snap/firefox/common/.cache" \
    "$HOME/snap/chromium/common/.cache"
}

bcc::stop_browsers() {
  local proc
  for proc in "${BROWSER_PROCESSES[@]}"; do
    if [[ ${DRY_RUN:-0} == 1 ]]; then
      log::info "[DRY-RUN] pkill -x ${proc}"
    else
      pkill -x "$proc" 2> /dev/null || true # no match is fine
    fi
  done
}

bcc::clear_dir() {
  local dir="$1"
  [[ -d $dir ]] || return 0

  local size
  size=$(du -sh -- "$dir" 2> /dev/null | cut -f1)

  # dir::remove deletes unconditionally, so honor DRY_RUN here.
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[DRY-RUN] would clear ${dir} (${size:-?})"
    return 0
  fi
  log::info "clearing ${dir} (${size:-?})"
  dir::remove "$dir"
}

bcc::main() {
  case "${1:-}" in
    -h | --help)
      bcc::usage
      exit 0
      ;;
  esac

  bcc::stop_browsers

  local dir
  while IFS= read -r dir; do
    bcc::clear_dir "$dir"
  done < <(bcc::cache_dirs)

  log::info "browser caches cleared 🧹"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  bcc::main "$@"
fi
