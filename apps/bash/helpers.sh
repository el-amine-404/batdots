# apps/bash/helpers.sh
# shellcheck shell=bash
# Shared helpers loaded by both bashrc and profile.
# Idempotent: re-sourcing is safe.

# 1. CORE LIBRARY
# ------------------------------------------------------------------------------
# Dynamically find and load the central dotfiles library.
_helpers_root="$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)"
if [[ -f "${_helpers_root}/lib/bash-utilities.sh" ]]; then
  # Export root so the library can find itself
  export DOTFILES_ROOT="${_helpers_root}"
  # shellcheck source=/dev/null
  source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
else
  # Fallback for basic functions if repo is missing
  path::prepend() { export PATH="$1${PATH:+:$PATH}"; }
  dir::ensure() { [[ -d "$1" ]] || mkdir -p -- "$1"; }
fi
unset _helpers_root

# 2. BASH-SPECIFIC HELPERS
# ------------------------------------------------------------------------------

# True if a command is on PATH.
cmd::has() {
  command -v -- "$1" > /dev/null 2>&1
}

# Source every *.sh in a directory, in lexical order.
# Uses nullglob locally so an empty dir is a no-op (not an error).
shell::source_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  local script restore_nullglob=0
  shopt -q nullglob || restore_nullglob=1
  shopt -s nullglob
  for script in "$dir"/*.sh; do
    [[ -r "$script" ]] && source "$script"
  done
  ((restore_nullglob)) && shopt -u nullglob
  return 0
}

# shopt that doesn't fail if the option doesn't exist on this bash version.
shell::shopt() {
  shopt -s "$1" > /dev/null 2>&1 || true
}
