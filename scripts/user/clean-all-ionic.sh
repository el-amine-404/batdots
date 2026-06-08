#!/usr/bin/env bash
# scripts/user/clean-all-ionic.sh -- Clean every Ionic project under <target>.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

# Ionic has no native `clean` command -- we just rm the heavy build dirs.
readonly CI_MANUAL_CLEAN=(
  node_modules platforms plugins www .idea .vscode
  android/.gradle android/.cxx android/build android/app/build
  ios/Pods ios/build ios/DerivedData
  .angular .angular/cache build dist .capacitor
  .eslintcache coverage
)

ci::clean_one() {
  local dir="$1"
  log::info "Cleaning Ionic project: $dir"
  (
    cd "$dir" || exit 1
    local item
    for item in "${CI_MANUAL_CLEAN[@]}"; do
      [[ -e $item ]] || continue
      log::debug "removing $item"
      rm -rf -- "$item"
    done
  )
}

ci::main() {
  banner::print "clean ionic"
  local target="${1:-$PWD}"
  project::for_each_matching project::is_ionic "$target" ci::clean_one
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ci::main "$@"
fi
