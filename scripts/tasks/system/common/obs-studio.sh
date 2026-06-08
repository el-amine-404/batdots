#!/usr/bin/env bash
# scripts/tasks/system/common/obs-studio.sh
# Renders OBS configuration files from templates using local env variables.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

: "${DOTFILES_OBS_REC_DIR:?DOTFILES_OBS_REC_DIR not set}"
OBS_STREAM_KEY="${DOTFILES_OBS_STREAM_KEY:-}"

OBS_ROOT="${DOTFILES_ROOT}/apps/obs-studio"
PROFILE_DIR="${OBS_ROOT}/profiles/main"

# 1. Render basic.ini
log::info "  Rendering OBS basic.ini"
file::render_template \
  "${PROFILE_DIR}/basic.ini.template" \
  "${PROFILE_DIR}/basic.ini" \
  "OBS_RECORDING_PATH=${DOTFILES_OBS_REC_DIR}"

# 2. Render service.json
log::info "  Rendering OBS service.json"
file::render_template \
  "${PROFILE_DIR}/service.json.template" \
  "${PROFILE_DIR}/service.json" \
  "OBS_STREAM_KEY=${OBS_STREAM_KEY}"

chmod 0600 "${PROFILE_DIR}/basic.ini" "${PROFILE_DIR}/service.json"
