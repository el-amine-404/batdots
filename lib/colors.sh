#!/usr/bin/env bash
# lib/colors.sh -- high-performance color definitions with safe fallbacks.
#
# Optimized for bare-metal systems, containers, and standard desktops.
# Automatically disables colors if the output is not a TTY or if NO_COLOR is set.

# 1. Capability Detection
# ------------------------------------------------------------------------------
_colors::detect() {
  # Disable if NO_COLOR is set (https://no-color.org/)
  [[ -n "${NO_COLOR:-}" ]] && return 1
  # Disable if terminal is "dumb"
  [[ "${TERM:-}" == "dumb" ]] && return 1
  # Enable if output is a TTY
  [[ -t 1 ]] && return 0
  # Enable if user explicitly forced color (common in CI/CD)
  [[ "${FORCE_COLOR:-0}" == "1" ]] && return 0

  return 1
}

if _colors::detect; then
  # 2. ANSI Escape Sequences (Zero Dependencies)
  # ----------------------------------------------------------------------------
  BOLD=$'\e[1m'
  DIM=$'\e[2m'
  UNDERLINE=$'\e[4m'
  REVERSE=$'\e[7m'
  BLINK=$'\e[5m'
  INVISIBLE=$'\e[8m'
  RESET=$'\e[0m'

  FG_BLACK=$'\e[30m'
  FG_RED=$'\e[31m'
  FG_GREEN=$'\e[32m'
  FG_YELLOW=$'\e[33m'
  FG_BLUE=$'\e[34m'
  FG_MAGENTA=$'\e[35m'
  FG_CYAN=$'\e[36m'
  FG_WHITE=$'\e[37m'
  FG_DEFAULT=$'\e[39m'

  BG_BLACK=$'\e[40m'
  BG_RED=$'\e[41m'
  BG_GREEN=$'\e[42m'
  BG_YELLOW=$'\e[43m'
  BG_BLUE=$'\e[44m'
  BG_MAGENTA=$'\e[45m'
  BG_CYAN=$'\e[46m'
  BG_WHITE=$'\e[47m'
  BG_DEFAULT=$'\e[49m'

  FG_BRIGHT_BLACK=$'\e[90m'
  FG_BRIGHT_RED=$'\e[91m'
  FG_BRIGHT_GREEN=$'\e[92m'
  FG_BRIGHT_YELLOW=$'\e[93m'
  FG_BRIGHT_BLUE=$'\e[94m'
  FG_BRIGHT_MAGENTA=$'\e[95m'
  FG_BRIGHT_CYAN=$'\e[96m'
  FG_BRIGHT_WHITE=$'\e[97m'
else
  # 3. Safe Fallbacks (Minimal/Log Installations)
  # ----------------------------------------------------------------------------
  BOLD="" DIM="" UNDERLINE="" REVERSE="" BLINK="" INVISIBLE="" RESET=""
  FG_BLACK="" FG_RED="" FG_GREEN="" FG_YELLOW="" FG_BLUE="" FG_MAGENTA="" FG_CYAN="" FG_WHITE="" FG_DEFAULT=""
  BG_BLACK="" BG_RED="" BG_GREEN="" BG_YELLOW="" BG_BLUE="" BG_MAGENTA="" BG_CYAN="" BG_WHITE="" BG_DEFAULT=""
  FG_BRIGHT_BLACK="" FG_BRIGHT_RED="" FG_BRIGHT_GREEN="" FG_BRIGHT_YELLOW="" FG_BRIGHT_BLUE="" FG_BRIGHT_MAGENTA="" FG_BRIGHT_CYAN="" FG_BRIGHT_WHITE=""
fi

# 4. Utilities
# ------------------------------------------------------------------------------
# shellcheck disable=SC2034
readonly \
  BOLD DIM UNDERLINE REVERSE BLINK INVISIBLE \
  RESET \
  FG_BLACK FG_RED FG_GREEN FG_YELLOW FG_BLUE FG_MAGENTA FG_CYAN FG_WHITE FG_DEFAULT \
  BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE BG_DEFAULT \
  FG_BRIGHT_BLACK FG_BRIGHT_RED FG_BRIGHT_GREEN FG_BRIGHT_YELLOW FG_BRIGHT_BLUE FG_BRIGHT_MAGENTA FG_BRIGHT_CYAN FG_BRIGHT_WHITE \
  || true

return 0

colors::draw_palette() {
  local fg bg
  # Only draw if color is supported
  if [[ -z $FG_RED ]]; then
    echo "Color support is disabled or not detected."
    return 0
  fi

  for fg in {30..37}; do
    for bg in {40..47}; do
      printf '\e[%s;%sm F:%s B:%s \e[0m' "$fg" "$bg" "$fg" "$bg"
    done
    printf '\n'
  done
}
