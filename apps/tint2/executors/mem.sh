#!/bin/bash

#  used_mem=$(free | awk '/Mem/ {printf "%d MiB\n", $3 / 1024.0, $2 / 1024.0 }')
used_mem=$(free -m | awk '/Mem\:/ { print $3 }')
#  mem=$(free -h | awk '/Mem\:/ { print $2 }')
# echo ~/.config/tint2/executors/icons/indicator-sensors-memory.svg
# echo " ${used_mem}/${mem}"
echo "  ${used_mem} MiB"
