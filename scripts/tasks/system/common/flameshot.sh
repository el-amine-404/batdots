#!/usr/bin/env bash
# scripts/tasks/system/common/flameshot.sh
# Generates flameshot.ini with a private savePath from local/env.sh.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

: "${DOTFILES_SCREENSHOT_DIR:?DOTFILES_SCREENSHOT_DIR not set}"

TEMPLATE_FILE="${DOTFILES_ROOT}/apps/flameshot/flameshot.ini.template"
OUTPUT_FILE="${DOTFILES_ROOT}/apps/flameshot/flameshot.ini"

log::info "  Rendering flameshot.ini"

file::render_template "$TEMPLATE_FILE" "$OUTPUT_FILE" "SAVE_PATH=${DOTFILES_SCREENSHOT_DIR}"
chmod 0600 "$OUTPUT_FILE"
