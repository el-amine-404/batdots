#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: SDKMAN SETUP
# Installs or Updates SDKMAN! and ensures it is ready for automation.
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/lib/sdkman.sh"

# Run the setup logic
sdkman::setup
