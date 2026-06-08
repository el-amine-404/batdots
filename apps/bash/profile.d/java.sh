# profile.d/java.sh -- Java (system install).
# shellcheck shell=bash
# SDKMAN, when present, wins by being sourced from bashrc.d/70-sdkman.sh later
# (and SDKMAN exports its own JAVA_HOME). This is the fallback for non-SDKMAN
# shells (cron, scripts, GUI launchers).
if [[ -x /usr/bin/javac ]]; then
  JAVA_HOME=$(dirname "$(dirname "$(readlink -f /usr/bin/javac)")")
  export JAVA_HOME
  path::append "$JAVA_HOME/bin"
fi
