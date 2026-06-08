#!/usr/bin/env bash
# scripts/user/use-java.sh -- Switch between Java versions using SDKMAN or update-alternatives.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

# Trap Ctrl+C (SIGINT) and exit immediately
trap 'log::warn "Interrupted by user. Exiting..."; exit 130' SIGINT

java::usage() {
  cat << EOF
Usage: $(basename "$0") <java_version_number> (e.g., 8, 11, 17, 21)

Switches Java version using SDKMAN (if detected) or system alternatives.
EOF
}

java::get_system_alternatives() {
  update-java-alternatives --list 2> /dev/null | awk '{print $1}' || :
}

java::switch_system() {
  local version="$1"
  local alternatives
  alternatives=$(java::get_system_alternatives)

  local target=""
  if printf '%s\n' "$alternatives" | grep -q "^java-1\.${version}\.0"; then
    target=$(printf '%s\n' "$alternatives" | grep "^java-1\.${version}\.0" | head -n 1)
  elif printf '%s\n' "$alternatives" | grep -q "^java-${version}"; then
    target=$(printf '%s\n' "$alternatives" | grep "^java-${version}" | head -n 1)
  fi

  if [[ -n $target ]]; then
    log::info "Switching system Java to: $target"
    ${SUDO_CMD:-sudo} update-java-alternatives --set "$target" || {
      log::error "System Java switch failed."
      return 1
    }
    return 0
  fi
  return 1
}

java::switch_sdkman() {
  local version="$1"
  local sdk_init="${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"

  [[ -f $sdk_init ]] || return 1

  # Sourcing SDKMAN requires set +u
  set +u
  # shellcheck source=/dev/null
  source "$sdk_init"

  log::info "SDKMAN detected. Searching for Java $version..."

  local target
  target=$(sdk list java | grep 'installed' | grep -E "\b${version}\." | awk '{print $NF}' | head -n 1)

  if [[ -n $target ]]; then
    log::info "Switching SDKMAN Java to: $target"
    sdk default java "$target"
    set -u
    return 0
  fi

  set -u
  log::error "Java $version not found in SDKMAN installed candidates."
  log::info "Please install it via SDKMAN first:"
  log::info "Command: sdk install java <version_from_sdk_list>"
  return 1
}

java::verify_active() {
  local requested="$1"
  local active_version
  active_version=$(java -version 2>&1 | head -n 1 | grep -oE '[0-9]+(\.[0-9]+)?' | head -n 1 | cut -d. -f1)

  [[ $active_version == "1" ]] && active_version="8"

  if [[ $active_version == "$requested" ]]; then
    log::info "SUCCESS: Active Java is now version $active_version"
    return 0
  fi

  log::warn "MISMATCH: Active 'java -version' is still $active_version."

  local java_path
  java_path=$(which java || echo "unknown")
  if [[ $java_path == *".sdkman"* ]]; then
    log::error "SDKMAN is currently overriding your PATH. Please install Java $requested via SDKMAN."
  fi
  return 1
}

java::main() {
  if [[ $# -ne 1 || $1 == "-h" || $1 == "--help" ]]; then
    java::usage
    exit 2
  fi

  local version="$1"
  banner::print "java"

  # 1. If SDKMAN is present, use it EXCLUSIVELY
  local sdk_init="${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"
  if [[ -f $sdk_init ]]; then
    if java::switch_sdkman "$version"; then
      java::verify_active "$version" || :
      return 0
    fi
    # Fail if SDKMAN is present but the version is missing
    exit 1
  fi

  # 2. Fallback to System Alternatives ONLY if SDKMAN is NOT present
  if command::exists update-java-alternatives; then
    if java::switch_system "$version"; then
      java::verify_active "$version" || :
      return 0
    fi
  fi

  log::error "Could not find Java $version in system alternatives."
  exit 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  java::main "$@"
fi
sleep 0.2
