#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

nemo_actions::resolve_target_dir() {
  if [[ -n ${DOTFILES_NEMO_ACTIONS_DIR:-} ]]; then
    printf '%s\n' "$DOTFILES_NEMO_ACTIONS_DIR"
    return
  fi
  local base="${XDG_DATA_HOME:-$HOME/.local/share}"
  printf '%s/nemo/actions\n' "$base"
}

nemo_actions::resolve_source_dir() {
  if [[ -n ${DOTFILES_NEMO_PERSONAL_ACTIONS_DIR:-} ]]; then
    printf '%s\n' "$DOTFILES_NEMO_PERSONAL_ACTIONS_DIR"
    return
  fi
  printf '%s/apps/nemo/actions\n' "$DOTFILES_ROOT"
}

nemo_actions::validate_paths() {
  local source_dir="$1" target_dir="$2"
  if [[ ! -d $source_dir ]]; then
    if [[ -n ${DOTFILES_NEMO_PERSONAL_ACTIONS_DIR:-} ]]; then
      log::fatal "DOTFILES_NEMO_PERSONAL_ACTIONS_DIR is set to '$source_dir' but the directory does not exist."
    fi
    log::warn "Personal actions directory '$source_dir' does not exist -- nothing to link."
    return 1
  fi
  local parent
  parent=$(dirname "$target_dir")
  if [[ ! -d $parent ]] && ! mkdir -p "$parent" 2> /dev/null; then
    log::fatal "Cannot create parent of target dir '$target_dir' -- check DOTFILES_NEMO_ACTIONS_DIR."
  fi
  if [[ -e $target_dir && ! -w $target_dir ]]; then
    log::fatal "Target dir '$target_dir' is not writable."
  fi
}

nemo_actions::_run() {
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] $*"
  else
    "$@"
  fi
}

nemo_actions::ensure_target_directory_exists() {
  local target_dir="$1"
  if [[ -d $target_dir ]]; then
    log::debug "Nemo actions directory already exists at $target_dir."
    return 0
  fi
  log::info "Creating the Nemo actions directory at $target_dir..."
  nemo_actions::_run mkdir -p "$target_dir"
}

nemo_actions::list_personal_actions() {
  local source_dir="$1"
  shopt -s nullglob
  local f
  for f in "$source_dir"/*; do
    [[ -f $f ]] || continue
    [[ $(basename "$f") == ".gitkeep" ]] && continue
    printf '%s\n' "$f"
  done
  shopt -u nullglob
}

nemo_actions::is_already_linked() {
  local src="$1" dest="$2"
  [[ -L $dest ]] || return 1
  [[ $(readlink -f "$dest") == "$(readlink -f "$src")" ]]
}

nemo_actions::link_one_action() {
  local src="$1" target_dir="$2"
  local name
  name=$(basename "$src")
  local dest="${target_dir}/${name}"

  if nemo_actions::is_already_linked "$src" "$dest"; then
    log::debug "Already linked: $name"
    return 0
  fi
  if [[ -e $dest && ! -L $dest ]]; then
    log::warn "Skipping '$name' -- a real file with that name already exists (likely a downloaded action)."
    return 0
  fi
  log::info "Linking personal action: $name"
  nemo_actions::_run ln -sfn "$src" "$dest"
  case "$name" in
    *.sh | *.py) nemo_actions::_run chmod +x "$src" ;;
  esac
}

nemo_actions::link_personal_actions() {
  local source_dir="$1" target_dir="$2"
  local actions
  mapfile -t actions < <(nemo_actions::list_personal_actions "$source_dir")
  if ((${#actions[@]} == 0)); then
    log::info "No personal actions found in '$source_dir' -- nothing to link yet."
    return 0
  fi
  local action
  for action in "${actions[@]}"; do
    nemo_actions::link_one_action "$action" "$target_dir"
  done
  log::info "Linked ${#actions[@]} personal action(s) alongside any Cinnamon Spices downloads."
}

main() {
  banner::print "nemo-actions"
  local source_dir target_dir
  source_dir=$(nemo_actions::resolve_source_dir)
  target_dir=$(nemo_actions::resolve_target_dir)
  log::debug "Source: $source_dir"
  log::debug "Target: $target_dir"
  nemo_actions::validate_paths "$source_dir" "$target_dir" || exit 0
  nemo_actions::ensure_target_directory_exists "$target_dir"
  nemo_actions::link_personal_actions "$source_dir" "$target_dir"
}

main "$@"
