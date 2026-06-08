# bashrc.d/70-sdkman.sh -- SDKMAN! (Java/Maven/Gradle/Groovy/Springboot version manager).
# shellcheck shell=bash
# Sourced late so anything earlier that touches PATH has already run.

export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
fi
