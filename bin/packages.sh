#!/usr/bin/env bash
# Package installation engine
#
# Each line in config/packages/<group>.txt is `<name>[:<manager>]`. When the
# manager is omitted, the line uses the distro's native manager. Names are
# resolved against config/package-managers/<manager>[.<distro>[.<codename>]].conf
# so a single generic name can map to per-distro package names.

declare -A _PKG_MAP_CHAIN=()
declare -A PKG_QUEUES=()

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

packages::_distro_family() {
  local distro="$1"
  local map="${DOTFILES_ROOT}/config/package-managers/family.conf"
  local family
  if [[ -f $map ]] && family=$(file::get_config_value "$map" "$distro"); then
    printf '%s' "$family"
  else
    printf '%s' "$distro"
  fi
}

packages::_map_chain() {
  local manager="$1"
  if [[ -n ${_PKG_MAP_CHAIN[$manager]+x} ]]; then
    printf '%s' "${_PKG_MAP_CHAIN[$manager]}"
    return 0
  fi

  local dir="${DOTFILES_ROOT}/config/package-managers"
  local distro codename family
  distro=$(os::get_distribution_id 2> /dev/null || true)
  codename=$(os::get_distribution_codename 2> /dev/null || true)
  [[ -n $distro ]] && family=$(packages::_distro_family "$distro")

  local candidates=()
  [[ -n $distro && -n $codename ]] && candidates+=("${dir}/${manager}.${distro}.${codename}.conf")
  [[ -n $distro ]] && candidates+=("${dir}/${manager}.${distro}.conf")
  [[ -n $family && $family != "$distro" ]] && candidates+=("${dir}/${manager}.${family}.conf")
  candidates+=("${dir}/${manager}.conf")

  local chain="" f
  for f in "${candidates[@]}"; do
    [[ -f $f ]] && chain+="${f}"$'\n'
  done

  _PKG_MAP_CHAIN[$manager]="$chain"
  printf '%s' "$chain"
}

packages::resolve_name() {
  local generic="$1" manager="$2"
  local chain f mapped
  chain=$(packages::_map_chain "$manager")
  while IFS= read -r f; do
    [[ -z $f ]] && continue
    if mapped=$(file::get_config_value "$f" "$generic"); then
      printf '%s' "$mapped"
      return 0
    fi
  done <<< "$chain"
  printf '%s' "$generic"
}

packages::_build_queues() {
  local native="$1"
  shift
  local groups=("$@")

  PKG_QUEUES=()

  local group list line name manager resolved
  for group in "${groups[@]}"; do
    list="${DOTFILES_ROOT}/config/packages/${group}.txt"
    if [[ ! -f $list ]]; then
      log::warn "Package list not found: ${group} (skipping)"
      continue
    fi
    log::debug "Reading group: ${group}"

    while IFS= read -r line || [[ -n $line ]]; do
      line="${line%%#*}"
      line=$(string::trim "$line")
      [[ -z $line ]] && continue

      name="${line%%:*}"
      manager="${line##*:}"
      [[ $name == "$manager" ]] && manager="$native"

      resolved=$(packages::resolve_name "$name" "$manager")
      PKG_QUEUES[$manager]+="$resolved"$'\n'
    done < "$list"
  done
}

packages::collect_unavailable() {
  local manager batch pkg
  for manager in "${!PKG_QUEUES[@]}"; do
    mapfile -t batch < <(printf '%s' "${PKG_QUEUES[$manager]}" | grep -v '^$')
    [[ ${#batch[@]} -eq 0 ]] && continue

    case "$manager" in
      flatpak | snap | cargo) continue ;;
    esac

    unset -f pkg_unavailable 2> /dev/null || true
    packages::load_adapter "$manager"
    declare -F pkg_unavailable > /dev/null || continue

    while IFS= read -r pkg; do
      [[ -z $pkg ]] && continue
      printf '%s\t%s\n' "$manager" "$pkg"
    done < <(pkg_unavailable "${batch[@]}")
  done
}

packages::preflight() {
  local rows
  rows=$(packages::collect_unavailable)
  [[ -z $rows ]] && return 0

  local distro codename
  distro=$(os::get_distribution_id 2> /dev/null || echo "unknown")
  codename=$(os::get_distribution_codename 2> /dev/null || echo "unknown")

  log::error "Pre-flight check failed on ${distro} (${codename}): some packages have no install candidate."
  log::error "This is a packaging-map gap in batdots, not a problem with your machine -- nothing was installed."
  log::error ""

  local manager pkg prev=""
  while IFS=$'\t' read -r manager pkg; do
    [[ -z $manager ]] && continue
    if [[ $manager != "$prev" ]]; then
      log::error "  unavailable via ${manager}:"
      prev="$manager"
    fi
    log::error "    - ${pkg}"
  done <<< "$rows"

  log::error ""
  log::error "Fix it one of these ways:"
  log::error "  1. Map the correct name for your distro in"
  log::error "     config/package-managers/<mgr>.${distro}.conf"
  log::error "     (or <mgr>.${distro}.${codename}.conf if it differs between releases)."
  log::error "  2. If your package manager genuinely can't provide it, drop it from the map and"
  log::error "     install it from the font registry or a source-build task instead."
  log::error "  3. Open an issue or PR: https://github.com/el-amine-404/batdots"
  log::fatal "Aborting before any package is installed."
}

packages::install_groups() {
  local native="$1"
  shift

  packages::_build_queues "$native" "$@"
  packages::preflight

  local manager batch
  for manager in "${!PKG_QUEUES[@]}"; do
    mapfile -t batch < <(printf '%s' "${PKG_QUEUES[$manager]}" | grep -v '^$')
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
