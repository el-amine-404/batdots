#!/usr/bin/env bash

task::resolve_path() {
  local category="$1"
  local task_name="$2"

  local search_chain=()

  if [[ -n ${OS_ID-} ]]; then
    search_chain+=("${OS_ID}")
  fi

  if [[ -n ${OS_ID_LIKE-} ]]; then
    read -ra family_ids <<< "$OS_ID_LIKE"
    search_chain+=("${family_ids[@]}")
  fi

  search_chain+=("common")

  for variant in "${search_chain[@]}"; do
    local candidate="${DOTFILES_ROOT}/scripts/tasks/${category}/${variant}/${task_name}.sh"

    if [[ -f $candidate ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

task::run() {
  local category="${1:?Error: Category is required}"
  local task_name="${2:?Error: Task name is required}"

  local script_path
  if ! script_path=$(task::resolve_path "$category" "$task_name"); then
    log::error "Task implementation not found: [${category}/${task_name}]"
    log::debug "Searched strategy: [${OS_ID} -> ${OS_ID_LIKE:-} -> common]"
    return 1
  fi

  local context
  context=$(basename "$(dirname "$script_path")")

  log::info "Running task [${task_name}] (${context})..."

  if bash "$script_path"; then
    log::info "Task [${task_name}] completed."
    return 0
  else
    log::error "Task [${task_name}] failed."
    return 1
  fi
}
