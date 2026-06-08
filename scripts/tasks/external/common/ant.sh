#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
source "${DOTFILES_ROOT}/lib/sdkman.sh"

# Pass "java" to look for config/devtools/java.list
sdkman::install_from_list "ant"
