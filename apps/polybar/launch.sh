#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/polybar"
CONFIG_FILE="$CONFIG_DIR/config.ini"
LOG_FILE="/tmp/polybar.log"
BARS=("example")

polybar::kill() {
  # if the bars have ipc (Inter-Process Communication) enabled
  if command -v polybar-msg &> /dev/null; then
    polybar-msg cmd quit > /dev/null 2>&1
  fi

  # fallback
  killall -q polybar

  while pgrep -u $UID -x polybar > /dev/null; do sleep 1; done
}

polybar::load() {
  local bar_name="${1?bar name required}"
  polybar --reload --config="$CONFIG_FILE" "$bar_name" 2>&1 | tee -a "$LOG_FILE" &
  disown
}

if [[ ! -f $CONFIG_FILE ]]; then
  echo "error: config file not found at $CONFIG_FILE"
  exit 1
fi

polybar::kill

echo "---" | tee -a "$LOG_FILE"

for bar in "${BARS[@]}"; do
  if grep -q "\[bar/$bar\]" "$CONFIG_FILE"; then
    polybar::load "$bar"
  else
    echo "WARNING: Bar '$bar' not found in config. Skipping."
  fi
done

echo "Bars launched successfully."
