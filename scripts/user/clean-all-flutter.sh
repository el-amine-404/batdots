#!/usr/bin/env bash
# scripts/user/clean-all-flutter.sh -- Clean every Flutter project under <target>.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

readonly CF_MANUAL_CLEAN=(build .dart_tool)

cf::clean_one() {
  local dir="$1"
  log::info "Cleaning Flutter project: $dir"
  (
    cd "$dir" || exit 1
    if command::exists flutter; then
      flutter clean > /dev/null 2>&1 || true
    else
      log::warn "flutter not found, falling back to rm"
      rm -rf -- "${CF_MANUAL_CLEAN[@]}"
    fi
  )
}

cf::main() {
  banner::print "clean flutter"
  local target="${1:-$PWD}"
  project::for_each_matching project::is_flutter "$target" cf::clean_one
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cf::main "$@"
fi
