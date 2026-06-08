#!/usr/bin/env bash
# scripts/user/rofi-scripts.sh -- Clean launcher for all your dotfiles utilities.
# Shows scripts without the .sh extension and handles the execution.
set -Eeuo pipefail

# 1. BOOTSTRAP
# ------------------------------------------------------------------------------
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

# 2. SELECTION
# ------------------------------------------------------------------------------
SCRIPT_DIR="${DOTFILES_ROOT}/scripts/user"

# Generate list of scripts (strip .sh and filter out this launcher)
generate_list() {
  find "$SCRIPT_DIR" -maxdepth 1 -name "*.sh" -not -name "$(basename "$0")" -printf "%f\n" \
    | sed 's/\.sh$//' | sort
}

log::info "Launching script menu..."

if ! SELECTED=$(generate_list | rofi -dmenu -i -p "🛠️ Scripts" -theme-str 'window {width: 40%;}'); then
  exit 0
fi

# 3. EXECUTION
# ------------------------------------------------------------------------------
TARGET_SCRIPT="${SCRIPT_DIR}/${SELECTED}.sh"

if [[ -x "$TARGET_SCRIPT" ]]; then
  log::info "Executing: $SELECTED"
  # Run in background and disown so rofi can close
  "$TARGET_SCRIPT" &
else
  log::error "Script not found or not executable: $SELECTED"
  exit 1
fi
