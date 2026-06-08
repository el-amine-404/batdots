#!/usr/bin/env bash
# Package installation engine
#
# Each line in config/packages/<group>.txt is `<name>[:<manager>]`. When the
# manager is omitted, the line uses the distro's native manager. Names are
# resolved against config/package-managers/<manager>.conf so a single generic
# name can map to per-distro package names.

packages::detect_native_package_manager() {
  local distro map manager
  distro=$(os::get_distribution_id)
  map="${DOTFILES_ROOT}/config/package-managers/distro.conf"
  if manager=$(file::get_config_value "$map" "$distro"); then
    log::info "Native package manager: ${manager}"
    printf '%s' "$manager"
    return 0
  fi
  log::fatal "Unsupported distro: $distro (add it to ${map})"
}

packages::load_adapter() {
  local manager="$1"
  local adapter="${DOTFILES_ROOT}/lib/pkg/${manager}.sh"
  [[ -f $adapter ]] || log::fatal "No adapter for '${manager}' at ${adapter}"
  # shellcheck source=/dev/null
  source "$adapter"
  log::debug "Loaded adapter: ${manager}"
}

packages::resolve_name() {
  local generic="$1" manager="$2"
  local map="${DOTFILES_ROOT}/config/package-managers/${manager}.conf"
  local mapped
  if [[ -f $map ]] && mapped=$(file::get_config_value "$map" "$generic"); then
    printf '%s' "$mapped"
  else
    printf '%s' "$generic"
  fi
}

packages::install_groups() {
  local native="$1"
  shift
  local groups=("$@")

  declare -A queues=()

  for group in "${groups[@]}"; do
    local list="${DOTFILES_ROOT}/config/packages/${group}.txt"
    if [[ ! -f $list ]]; then
      log::warn "Package list not found: ${group} (skipping)"
      continue
    fi
    log::info "Reading group: ${group}"

    while IFS= read -r line || [[ -n $line ]]; do
      line="${line%%#*}"
      line=$(string::trim "$line")
      [[ -z $line ]] && continue

      local name="${line%%:*}" manager="${line##*:}"
      [[ $name == "$manager" ]] && manager="$native"

      local resolved
      resolved=$(packages::resolve_name "$name" "$manager")
      queues[$manager]+="$resolved"$'\n'
    done < "$list"
  done

  for manager in "${!queues[@]}"; do
    mapfile -t batch < <(printf '%s' "${queues[$manager]}" | grep -v '^$')
    [[ ${#batch[@]} -eq 0 ]] && continue
    packages::_install_batch "$manager" "${batch[@]}"
  done
}

packages::_install_batch() {
  local manager="$1"
  shift
  local batch=("$@")

  log::info "Installing ${#batch[@]} package(s) via ${manager}: ${batch[*]}"

  case "$manager" in
    flatpak | snap | cargo)
      if ! command -v "$manager" &> /dev/null; then
        log::error "${manager} is required but not installed -- skipping ${batch[*]}"
        return 1
      fi
      ;;
  esac

  packages::load_adapter "$manager"
  declare -F pkg_setup &> /dev/null && pkg_setup
  declare -F pkg_update &> /dev/null && pkg_update
  pkg_install "${batch[@]}"
}
