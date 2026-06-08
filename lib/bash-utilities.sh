#!/usr/bin/env bash
# Entry point: source this file once to load every helper library.
# All library functions are namespaced (log::*, file::*, source::*, ...).

# Guard against being sourced twice.
[[ -n "${BASH_UTILITIES_LOADED:-}" ]] && return 0
BASH_UTILITIES_LOADED=1

BASH_UTILITIES_PARENT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"

# Export DOTFILES_ROOT if not already set.
# This works even if the calling script is symlinked.
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  export DOTFILES_ROOT
  DOTFILES_ROOT="$(dirname "$BASH_UTILITIES_PARENT_PATH")"
fi

# Project Identity
export DOTFILES_PROJECT_NAME="batdots"
export DOTFILES_PROJECT_DESCRIPTION="dotfiles management framework"

# Load personal configuration from local/env.sh if it exists.
bu::source_env() {
  local env_file="${DOTFILES_ROOT}/local/env.sh"
  [[ -r "$env_file" ]] && source "$env_file"
  return 0
}

# Alias for backward compatibility with bash-centric scripts.
shell::source_env() { bu::source_env "$@"; }
shell::get_repo_root() { printf '%s' "${DOTFILES_ROOT}"; }

_bu::source() {
  local script="${BASH_UTILITIES_PARENT_PATH}/${1}.sh"
  if [[ -r $script ]]; then
    # shellcheck source=/dev/null
    source "$script"
  else
    printf 'bash-utilities: cannot source %s\n' "$script" >&2
    return 1
  fi
}

# Order matters: log depends on colors, everything else depends on log.
_bu::source colors
_bu::source log
_bu::source path
_bu::source argument
_bu::source confirmation
_bu::source string
_bu::source registry
_bu::source command
_bu::source os
_bu::source file
_bu::source dir
_bu::source archive
_bu::source backup
_bu::source project
_bu::source http
_bu::source git
_bu::source github
_bu::source gitlab
_bu::source source
_bu::source build
_bu::source status
_bu::source installer
_bu::source fonts
_bu::source node
_bu::source sdkman
_bu::source themes
_bu::source docs
_bu::source pdf
_bu::source image
_bu::source video
_bu::source audio
_bu::source notification
_bu::source banner
_bu::source prayer

# Automatically load personal environment if it exists.
# This ensures that all scripts sourcing bash-utilities.sh have access
# to namespaced DOTFILES_* configuration immediately.
# Loaded last so all helpers (like path::prepend) are defined first.
bu::source_env

# Initialize PATH for this session
path::setup

unset -f _bu::source
