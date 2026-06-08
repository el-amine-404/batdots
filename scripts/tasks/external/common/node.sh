#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EXTERNAL TASK: NODE.JS ECOSYSTEM
# Installs Node versions using FNM
# ==============================================================================

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/lib/node.sh"

node::install_from_list "node"
