#!/usr/bin/env bash
# scripts/user/clean-all-dotnet.sh -- Clean every .NET project under <target>.
set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

readonly CD_MANUAL_CLEAN=(bin obj)

cd::clean_one() {
  local dir="$1"
  log::info "Cleaning .NET project: $dir"
  (
    cd "$dir" || exit 1
    if command::exists dotnet; then
      dotnet clean > /dev/null 2>&1 || true
    else
      log::warn "dotnet not found, falling back to rm"
      rm -rf -- "${CD_MANUAL_CLEAN[@]}"
    fi
  )
}

cd::main() {
  banner::print "clean dotnet"
  local target="${1:-$PWD}"
  project::for_each_matching project::is_dotnet "$target" cd::clean_one
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cd::main "$@"
fi
