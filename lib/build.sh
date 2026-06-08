#!/usr/bin/env bash
# Shared helpers for source-build tasks. Sourced by every script under
# scripts/tasks/external/. Requires DOTFILES_ROOT, SUDO_CMD, and lib/log.sh
# to be in scope.

# Guard against double-sourcing
[[ -n "${BUILD_SH_LOADED:-}" ]] && return 0
BUILD_SH_LOADED=1

readonly BUILD_PREFIX="/usr/local"
readonly BUILD_SRC_DIR="/usr/local/src"

build::nproc() {
  nproc 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 1
}

build::ensure_ldconfig() {
  local triplet conf="/etc/ld.so.conf.d/local.conf"
  triplet=$(gcc -dumpmachine 2> /dev/null || echo "x86_64-linux-gnu")
  [[ -f $conf ]] && return 0

  log::info "Registering /usr/local/lib in ldconfig..."
  printf '/usr/local/lib\n/usr/local/lib64\n/usr/local/lib/%s\n' "$triplet" \
    | $SUDO_CMD tee "$conf" > /dev/null
  $SUDO_CMD ldconfig
}

build::ensure_pkg_config_path() {
  local triplet
  triplet=$(gcc -dumpmachine 2> /dev/null || echo "x86_64-linux-gnu")
  export PKG_CONFIG_PATH="${BUILD_PREFIX}/lib/${triplet}/pkgconfig:${BUILD_PREFIX}/lib/pkgconfig:${BUILD_PREFIX}/lib64/pkgconfig:${BUILD_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
  export LD_LIBRARY_PATH="${BUILD_PREFIX}/lib/${triplet}:${BUILD_PREFIX}/lib:${BUILD_PREFIX}/lib64:${LD_LIBRARY_PATH:-}"
  export PATH="${BUILD_PREFIX}/bin:${PATH}"
}

# Ensure meson is at least min_version; install via pip3 to ~/.local if not
build::ensure_modern_meson() {
  local min_version="${1:-1.3.0}"
  if command -v meson &> /dev/null; then
    local current
    current=$(meson --version)
    [[ "$(printf '%s\n%s' "$min_version" "$current" | sort -V | head -n1)" == "$min_version" ]] && return 0
    log::info "System meson (${current}) is older than ${min_version} -- upgrading"
  else
    log::info "Meson not found -- installing"
  fi

  python3 -m pip install --upgrade --user meson ninja --break-system-packages 2> /dev/null \
    || python3 -m pip install --upgrade --user meson ninja
  export PATH="${HOME}/.local/bin:${PATH}"

  command -v meson &> /dev/null || {
    log::error "meson install failed"
    return 1
  }
  log::info "meson available: $(meson --version)"
}

build::resolve_version() {
  local prefix="${1:?build::resolve_version requires a PREFIX}"
  local version_var="${prefix}_VERSION"
  local version="${!version_var:-}"
  if [[ -z $version ]]; then
    log::error "${prefix}_VERSION is not set in config/versions.conf"
    return 1
  fi
  printf '%s' "$version"
}

build::already_installed() {
  local module="$1" required="$2"
  build::ensure_pkg_config_path
  pkg-config --exists "$module" 2> /dev/null || return 1
  local installed
  installed=$(pkg-config --modversion "$module" 2> /dev/null || true)
  if [[ $installed == "$required" ]]; then
    log::info "${module} ${required} already installed -- skipping"
    return 0
  fi
  log::info "${module}: installed=${installed:-none}, required=${required} -- rebuilding"
  return 1
}

build::binary_already_installed() {
  local bin="$1" required="$2" version_cmd="$3"
  command -v "$bin" &> /dev/null || return 1
  local installed
  installed=$(bash -c "$version_cmd" 2> /dev/null || true)
  if [[ $installed == "$required" ]]; then
    log::info "${bin} ${required} already installed -- skipping"
    return 0
  fi
  log::info "${bin}: installed=${installed:-none}, required=${required} -- rebuilding"
  return 1
}

build::git_is_current() {
  local name="$1" bin="${2:-}"
  local dest="${BUILD_SRC_DIR}/${name}"
  local hash_file="${dest}/.built_hash"
  [[ -d "${dest}/.git" && -f "$hash_file" ]] || return 1
  [[ -n $bin ]] && ! command -v "$bin" &> /dev/null && return 1
  local current
  current=$(git -C "$dest" rev-parse HEAD 2> /dev/null) || return 1
  [[ "$(< "$hash_file")" == "$current" ]]
}

build::git_mark_built() {
  local name="$1"
  local dest="${BUILD_SRC_DIR}/${name}"
  git -C "$dest" rev-parse HEAD > "${dest}/.built_hash" 2> /dev/null || true
}

# Per-command git options. Avoids mutating the user's global git config.
_build_git_opts=(
  -c http.postBuffer=524288000
  -c http.lowSpeedLimit=0
  -c http.lowSpeedTime=999999
  -c http.version=HTTP/1.1
)

# Download and extract a tarball into BUILD_SRC_DIR/<name>-<version>.
# Returns the extracted directory path.
build::fetch_tarball() {
  local name="$1" version="$2" url="$3"
  local dest="${BUILD_SRC_DIR}/${name}-${version}"

  $SUDO_CMD mkdir -p "$dest"
  $SUDO_CMD chown "$(id -u):$(id -g)" "$dest"

  local tar_flag
  case "$url" in
    *.tar.xz | *.txz) tar_flag="-xJf" ;;
    *.tar.bz2 | *.tbz2) tar_flag="-xjf" ;;
    *) tar_flag="-xzf" ;;
  esac

  log::info "Downloading ${name} ${version}..."
  if ! curl -fsSL --connect-timeout 30 --max-time 600 "$url" \
    | tar "$tar_flag" - --strip-components=1 -C "$dest"; then
    log::error "Failed to fetch ${name} ${version} from ${url}"
    return 1
  fi
  printf '%s' "$dest"
}

# Clone or update a git repo at branch/tag. Pass --recursive as $4 for submods.
build::fetch_git() {
  local name="$1" url="$2" branch="$3" recursive="${4:-}"
  local dest="${BUILD_SRC_DIR}/${name}"
  local jobs
  jobs=$(build::nproc)

  if [[ -d "${dest}/.git" ]]; then
    log::info "Updating ${name}..."
    git "${_build_git_opts[@]}" -C "$dest" fetch --depth=1 origin "$branch" --quiet >&2
    git -C "$dest" reset --hard FETCH_HEAD --quiet >&2
    [[ $recursive == "--recursive" ]] \
      && git "${_build_git_opts[@]}" -C "$dest" submodule update --init --recursive --depth=1 --jobs="$jobs" --quiet >&2
  else
    $SUDO_CMD mkdir -p "$dest"
    $SUDO_CMD chown "$(id -u):$(id -g)" "$dest"
    log::info "Cloning ${name}..."
    local clone_args=(--branch "$branch" --depth 1 --filter=blob:none)
    [[ $recursive == "--recursive" ]] \
      && clone_args+=(--recurse-submodules --shallow-submodules --jobs="$jobs")
    git "${_build_git_opts[@]}" clone "${clone_args[@]}" "$url" "$dest" >&2
  fi
  printf '%s' "$dest"
}

build::cmake_install() {
  local src_dir="$1"
  shift
  local build_dir="${src_dir}/build"
  mkdir -p "$build_dir"

  log::info "Configuring (cmake)..."
  cmake -S "$src_dir" -B "$build_dir" \
    -DCMAKE_INSTALL_PREFIX="$BUILD_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    "$@" > /dev/null

  log::info "Compiling... ($(build::nproc) cores)"
  cmake --build "$build_dir" --parallel "$(build::nproc)"

  log::info "Installing..."
  $SUDO_CMD cmake --install "$build_dir"
  $SUDO_CMD ldconfig
}

build::meson_install() {
  local src_dir="$1"
  shift
  local build_dir="${src_dir}/build"
  [[ -d $build_dir ]] && rm -rf "$build_dir"

  log::info "Configuring (meson)..."
  meson setup "$build_dir" "$src_dir" \
    --prefix="$BUILD_PREFIX" --buildtype=release "$@"

  log::info "Compiling... ($(build::nproc) cores)"
  ninja -C "$build_dir" -j "$(build::nproc)"

  log::info "Installing..."
  $SUDO_CMD ninja -C "$build_dir" install
  $SUDO_CMD ldconfig
}

build::make_install() {
  local src_dir="$1"
  shift
  (
    cd "$src_dir" || return 1
    if [[ -f autogen.sh ]]; then
      ./autogen.sh > /dev/null
    elif [[ ! -f configure && -f configure.ac ]]; then
      autoreconf -fiv > /dev/null
    fi
    log::info "Configuring (autoconf)..."
    ./configure --prefix="$BUILD_PREFIX" "$@" > /dev/null
    log::info "Compiling... ($(build::nproc) cores)"
    make -j "$(build::nproc)"
    log::info "Installing..."
    $SUDO_CMD make install
    $SUDO_CMD ldconfig
  )
}

build::verify_pkgconfig() {
  local module="$1"
  build::ensure_pkg_config_path
  if ! pkg-config --exists "$module" 2> /dev/null; then
    log::error "Verification failed: pkg-config cannot find '${module}'"
    return 1
  fi
  log::info "Verified: ${module} $(pkg-config --modversion "$module")"
}

build::verify_binary() {
  local bin="$1"
  if ! command -v "$bin" &> /dev/null; then
    log::error "Verification failed: '${bin}' not in PATH"
    return 1
  fi
  log::info "Verified: ${bin} at $(command -v "$bin")"
}

build::purge_system_package() {
  local pkg="$1"
  log::info "Purging system package: ${pkg}"
  if command -v apt-get &> /dev/null; then
    $SUDO_CMD apt-get remove --purge -y "$pkg" 2> /dev/null || true
    $SUDO_CMD apt-get autoremove -y 2> /dev/null || true
  elif command -v dnf &> /dev/null; then
    $SUDO_CMD dnf remove -y "$pkg" 2> /dev/null || true
  elif command -v pacman &> /dev/null; then
    $SUDO_CMD pacman -Rs --noconfirm "$pkg" 2> /dev/null || true
  fi
}

build::install_system_package() {
  local pkg="$1"
  log::info "Installing system package: ${pkg}"
  if command -v apt-get &> /dev/null; then
    $SUDO_CMD apt-get update -qq && $SUDO_CMD apt-get install -y "$pkg"
  elif command -v dnf &> /dev/null; then
    $SUDO_CMD dnf install -y "$pkg"
  elif command -v pacman &> /dev/null; then
    $SUDO_CMD pacman -S --noconfirm "$pkg"
  fi
}

build::cleanup() {
  local name="$1"
  [[ "${CLEANUP_BUILD_SRC:-false}" == "true" ]] || return 0
  local dest="${BUILD_SRC_DIR}/${name}"
  log::info "Cleaning up source directory: $dest"
  $SUDO_CMD rm -rf "$dest"
}
