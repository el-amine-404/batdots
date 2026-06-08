#!/usr/bin/env bash
# scripts/tasks/system/common/vscode.sh
# Renders VSCode settings.json from template using local env variables.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

: "${DOTFILES_VSCODE_PROJECT_ID:?DOTFILES_VSCODE_PROJECT_ID not set}"

VSCODE_ROOT="${DOTFILES_ROOT}/apps/vscode"

log::info "  Rendering VSCode settings.json"
file::render_template \
  "${VSCODE_ROOT}/settings.json.template" \
  "${VSCODE_ROOT}/settings.json" \
  "VSCODE_GEMINI_PROJECT=${DOTFILES_VSCODE_PROJECT_ID}"

chmod 0600 "${VSCODE_ROOT}/settings.json"
