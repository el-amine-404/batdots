#!/usr/bin/env bash
# Installed-version detection for registry components -- offline, no network.
#
# Reads the <COMP>_PROBE and <COMP>_VERSION fields from config/versions.conf
# (the caller is responsible for sourcing it) and reports the installed copy.
# Shared by scripts/user/package-status.sh and bin/doctor.sh so the detection
# logic lives in exactly one place. Side-effect-free: defines functions only.
#
# PROBE grammar (see config/versions.conf header):
#   bin:NAME[:REGEX]   resolve NAME, read a version flag (REGEX overrides extract)
#   pkgconfig:MODULE   pkg-config --modversion MODULE
#   path:PATH          presence only (~ expanded) -> present / missing

# Default extraction: first "x.y[.z][-build]" token in a tool's --version output.
STATUS_VERSION_REGEX='[0-9]+\.[0-9]+([._-][0-9A-Za-z]+)*'

# Try a binary's common version flags (then a bare banner) and echo the first
# version-looking token. stdin is closed, DISPLAY/WAYLAND_DISPLAY are unset (so a
# GUI app handed an unknown flag fails fast instead of launching), and each call
# is time-boxed -- a probe can never hang the caller.
status::_bin_version() {
  local bin="$1" regex="${2:-$STATUS_VERSION_REGEX}"
  # env -u drops DISPLAY/WAYLAND so a GUI app given an unknown flag errors out
  # immediately instead of opening a window.
  local nogui=(env -u DISPLAY -u WAYLAND_DISPLAY timeout 3)
  local flag out version
  for flag in --version version -version -V -v; do
    out=$("${nogui[@]}" "$bin" "$flag" < /dev/null 2> /dev/null) || out=""
    version=$(grep -oiP "$regex" <<< "$out" | head -1 || true)
    [[ -n $version ]] && {
      printf '%s' "$version"
      return 0
    }
  done
  out=$("${nogui[@]}" "$bin" < /dev/null 2>&1 || true) # last resort: bare banner
  grep -oiP "$regex" <<< "$out" | head -1 || true
}

# echo "present" if a (~-expanded) path exists, else "missing".
status::_path_state() {
  local p="${1/#\~/$HOME}"
  [[ -e $p ]] && printf 'present' || printf 'missing'
}

# Strip a leading v / V / n release prefix for comparison.
status::_normalize() { printf '%s' "${1#[vVn]}"; }

# Installed state of a component: a version string, or present / missing / n/a.
status::installed_version() {
  local comp="$1"
  local probe_var="${comp}_PROBE"
  local probe="${!probe_var:-}"
  [[ -z $probe ]] && {
    printf 'n/a'
    return 0
  }

  local kind="${probe%%:*}" arg="${probe#*:}"
  case "$kind" in
    bin)
      local name="${arg%%:*}" regex=""
      [[ $arg == *:* ]] && regex="${arg#*:}"
      command::exists "$name" || {
        printf 'missing'
        return 0
      }
      local version
      version=$(status::_bin_version "$name" "$regex")
      printf '%s' "${version:-present}"
      ;;
    pkgconfig)
      command::exists pkg-config || {
        printf 'n/a'
        return 0
      }
      local version
      version=$(pkg-config --modversion "$arg" 2> /dev/null || true)
      printf '%s' "${version:-missing}"
      ;;
    path) status::_path_state "$arg" ;;
    *) printf 'n/a' ;;
  esac
}

# Compare installed vs pinned. Echoes "state|installed|pinned" where
# state ∈ ok | outdated | missing | na. A presence-only probe or a non-semver
# pin (latest/master/main/stable/...) can confirm presence but not a version, so
# it resolves to ok when installed.
status::compare() {
  local comp="$1"
  local pinned_var="${comp}_VERSION"
  local pinned="${!pinned_var:-?}"
  local installed
  installed=$(status::installed_version "$comp")

  case "$installed" in
    n/a) printf 'na|n/a|%s' "$pinned" ;;
    missing) printf 'missing|missing|%s' "$pinned" ;;
    present) printf 'ok|present|%s' "$pinned" ;;
    *)
      if [[ ! $pinned =~ ^[0-9] ]]; then
        printf 'ok|%s|%s' "$installed" "$pinned"
      elif [[ "$(status::_normalize "$installed")" == "$(status::_normalize "$pinned")" ]]; then
        printf 'ok|%s|%s' "$installed" "$pinned"
      else
        printf 'outdated|%s|%s' "$installed" "$pinned"
      fi
      ;;
  esac
}
