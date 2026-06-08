#!/usr/bin/env bash
# lib/path.sh -- PATH manipulation utilities.

# Add a directory to the beginning of PATH (no duplicates, must exist).
path::prepend() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  # Normalize path (remove trailing slash)
  dir="${dir%/}"
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir${PATH:+:$PATH}" ;;
  esac
  return 0
}

# Add a directory to the end of PATH (no duplicates, must exist).
path::append() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  # Normalize path
  dir="${dir%/}"
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="${PATH:+$PATH:}$dir" ;;
  esac
  return 0
}

# Standardize the environment PATH for dotfiles.
path::setup() {
  dir::ensure "$HOME/bin"
  dir::ensure "$HOME/.local/bin"

  # Prepend so personal scripts win over distro packages with the same name.
  path::prepend "$HOME/.local/bin"
  path::prepend "$HOME/.local/bin/dotfiles"
  path::prepend "$HOME/bin"

  # Support custom machine-specific paths from local/env.sh
  if [[ -n ${DOTFILES_EXTRA_PATHS[*]:-} ]]; then
    local _p
    for _p in "${DOTFILES_EXTRA_PATHS[@]}"; do
      path::prepend "$_p"
    done
  fi
}
