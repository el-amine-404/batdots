#!/usr/bin/env bash
set -u

ICON_DIR="$(dirname "$0")/icons"

read -r cpu a b c previdle rest < /proc/stat
prevtotal=$((a + b + c + previdle))

sleep 0.5

read -r cpu a b c idle rest < /proc/stat
total=$((a + b + c + idle))

diff_idle=$((idle - previdle))
diff_total=$((total - prevtotal))
usage=$((100 * (diff_total - diff_idle) / diff_total))
#   echo ~/.config/tint2/executors/icons/indicator-cpufreq.svg
echo "${ICON_DIR}/indicator-cpufreq.svg"
echo "  $usage%"
