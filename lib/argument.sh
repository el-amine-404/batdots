#!/usr/bin/env bash
# Verify each named variable is set and non-empty (after stripping whitespace).
# Returns non-zero on the first failure; the caller chooses how to react.
# Usage: argument::require_not_empty FOO BAR BAZ
argument::require_not_empty() {
  local name value
  for name in "$@"; do
    if ! declare -p "$name" &> /dev/null; then
      log::error "${name} is required and cannot be empty"
      return 1
    fi
    value="${!name}"
    if [[ -z "${value//[[:space:]]/}" ]]; then
      log::error "${name} is required and cannot be empty"
      return 1
    fi
  done
}

# Returns 0 if input is a valid integer (optionally signed).
argument::is_int() {
  [[ "${1:-}" =~ ^-?[0-9]+$ ]]
}

# Returns 0 if the first argument is an integer between the second and third.
# Usage: argument::is_in_range 50 0 100
argument::is_in_range() {
  local val="${1:-}" min="${2:-}" max="${3:-}"
  argument::is_int "$val" || return 1
  ((val >= min && val <= max))
}
