#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: GIT COMPLETION
# Enables TAB autocompletion for git commands (essential).
# ==============================================================================

source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/config/versions.conf"

DEST_DIR="${HOME}/.local/share/git-core"
URL=$(source::resolve_repo_url "GIT_COMPLETION")

mkdir -p "$DEST_DIR"

DEST_FILE="${DEST_DIR}/git-completion.bash"

if http::download "$URL" "$DEST_FILE"; then
  log::info "Git completion installed."
else
  log::error "Failed to download git-completion.bash"
  exit 1
fi
