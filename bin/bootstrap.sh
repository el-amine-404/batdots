#!/usr/bin/env bash
# Entry point: provisions a machine from manifests/<profile>.conf in four phases
# -- system tasks, packages, external builds, symlinks. See --help for options.
set -Eeuo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DOTFILES_ROOT

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/bin/packages.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/bin/task.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/bin/linker.sh"

PROFILE_NAME=""
CLEANUP_BUILD_SRC=false
UPDATE_VERSIONS=false
DRY_RUN=0
SKIP_TASKS=0
SKIP_PACKAGES=0
SKIP_EXTERNAL=0
SKIP_SYMLINKS=0

bootstrap::print_help() {
  cat << EOF
Usage: $(basename "$0") --profile <name> [options]

Options:
  -p, --profile <name>   Profile to apply (manifests/<name>.conf). Required.
  -u, --update           Refresh versions.conf from upstream before building.
      --cleanup          Remove source directories after a successful build.
  -n, --dry-run          Print what would happen without changing anything.
                         Skips package installs and external builds entirely;
                         routes symlink writes through DRY_RUN=1.
      --skip-tasks       Skip the SYSTEM_TASKS phase.
      --skip-packages    Skip the PACKAGES phase.
      --skip-external    Skip the EXTERNAL builds phase.
      --skip-symlinks    Skip the SYMLINKS phase.
  -h, --help             Show this help.

Available profiles:
$(for f in "$DOTFILES_ROOT"/manifests/*.conf; do printf '  - %s\n' "$(basename "$f" .conf)"; done)
EOF
}

bootstrap::parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p | --profile)
        PROFILE_NAME="${2:?--profile requires an argument}"
        shift
        ;;
      -u | --update) UPDATE_VERSIONS=true ;;
      --cleanup) CLEANUP_BUILD_SRC=true ;;
      -n | --dry-run) DRY_RUN=1 ;;
      --skip-tasks) SKIP_TASKS=1 ;;
      --skip-packages) SKIP_PACKAGES=1 ;;
      --skip-external) SKIP_EXTERNAL=1 ;;
      --skip-symlinks) SKIP_SYMLINKS=1 ;;
      -h | --help)
        bootstrap::print_help
        exit 0
        ;;
      *) log::fatal "Unknown argument: $1" ;;
    esac
    shift
  done

  [[ -n $PROFILE_NAME ]] || {
    bootstrap::print_help
    log::fatal "--profile is required"
  }

  export DRY_RUN CLEANUP_BUILD_SRC
}

bootstrap::load_profile() {
  banner::splash "${DOTFILES_PROJECT_NAME}" "${DOTFILES_PROJECT_DESCRIPTION}"

  OS_ID="$(os::get_distribution_id)"
  OS_ID_LIKE="$(os::get_distribution_id_like || true)"
  export OS_ID OS_ID_LIKE
  log::info "Detected OS: ${OS_ID} (like: ${OS_ID_LIKE:-none})"

  local profile_file="${DOTFILES_ROOT}/manifests/${PROFILE_NAME}.conf"
  [[ -f $profile_file ]] || log::fatal "Profile not found: $profile_file"

  log::info "Loading profile: $PROFILE_NAME"
  # shellcheck disable=SC1090
  source "$profile_file"
  export PROFILE

  if ((DRY_RUN)); then
    log::info "DRY-RUN mode: no system changes will be made."
  fi
}

bootstrap::resolve_privileges() {
  # Sudo is only needed for system tasks, packages, or external builds -- never
  # for symlinks or dry-runs. Skipping the prompt otherwise lets the symlink
  # layer be re-applied without a password.
  local needs_sudo=0
  if ((!DRY_RUN)); then
    [[ $SKIP_TASKS == 0 && -n ${SYSTEM_TASKS[*]:-} ]] && needs_sudo=1
    [[ $SKIP_PACKAGES == 0 && -n ${PACKAGES[*]:-} ]] && needs_sudo=1
    [[ $SKIP_EXTERNAL == 0 && -n ${EXTERNAL[*]:-} ]] && needs_sudo=1
  fi

  if ((needs_sudo)); then
    os::detect_privilege_tool
  else
    log::debug "no privileged phases requested -- skipping sudo check"
    export SUDO_CMD=""
  fi
}

bootstrap::maybe_update_versions() {
  [[ $UPDATE_VERSIONS == true ]] || return 0
  log::info "Refreshing versions.conf from upstream..."
  "${DOTFILES_ROOT}/scripts/maintenance/fetch-versions.sh"
  # shellcheck source=/dev/null
  source "${DOTFILES_ROOT}/config/versions.conf"
}

bootstrap::run_system_tasks() {
  if ((SKIP_TASKS)) || [[ -z ${SYSTEM_TASKS[*]:-} ]]; then return 0; fi
  local name
  for name in "${SYSTEM_TASKS[@]}"; do
    if ((DRY_RUN)); then
      log::info "[dry-run] would run system task: $name"
    else
      task::run "system" "$name"
    fi
  done
}

bootstrap::install_packages() {
  if ((SKIP_PACKAGES)) || [[ -z ${PACKAGES[*]:-} ]]; then return 0; fi
  if ((DRY_RUN)); then
    log::info "[dry-run] would install package groups: ${PACKAGES[*]}"
    return 0
  fi
  local native_mgr
  native_mgr=$(packages::detect_native_package_manager)
  packages::install_groups "$native_mgr" "${PACKAGES[@]}"
}

bootstrap::build_external() {
  if ((SKIP_EXTERNAL)) || [[ -z ${EXTERNAL[*]:-} ]]; then return 0; fi
  local name
  for name in "${EXTERNAL[@]}"; do
    if ((DRY_RUN)); then
      log::info "[dry-run] would build external: $name"
    else
      task::run "external" "$name"
    fi
  done
}

bootstrap::apply_symlinks() {
  if ((SKIP_SYMLINKS)) || [[ -z ${SYMLINKS[*]:-} ]]; then return 0; fi
  local conf
  for conf in "${SYMLINKS[@]}"; do
    linker::apply "$conf"
  done
}

bootstrap::report_completion() {
  if ((DRY_RUN)); then
    log::info "Dry-run complete (no changes were made)."
  else
    log::info "Bootstrap complete."
  fi
}

main() {
  bootstrap::parse_args "$@"
  bootstrap::load_profile
  bootstrap::resolve_privileges
  bootstrap::maybe_update_versions
  bootstrap::run_system_tasks
  bootstrap::install_packages
  bootstrap::build_external
  bootstrap::apply_symlinks
  bootstrap::report_completion
}

main "$@"
