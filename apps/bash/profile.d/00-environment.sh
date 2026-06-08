# profile.d/00-environment.sh -- environment variables (locale, editor, etc.).
# shellcheck shell=bash

# /etc/os-release exports NAME, VERSION, ID, ID_LIKE, PRETTY_NAME, ...
[[ -r /etc/os-release ]] && source /etc/os-release

# Editor -- first installed wins, with a sane fallback.
for _ed in nano nvim vim vi; do
  if cmd::has "$_ed"; then
    VISUAL=$(command -v "$_ed")
    export VISUAL
    export EDITOR="$VISUAL"
    break
  fi
done
unset _ed

# Locale -- keep all categories aligned, leave LC_ALL empty so per-category
# overrides remain effective.
export LANG=en_US.UTF-8
export LANGUAGE=en_US
export LC_CTYPE=en_US.UTF-8
export LC_NUMERIC=en_US.UTF-8
export LC_TIME=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8
export LC_MONETARY=en_US.UTF-8
export LC_MESSAGES=en_US.UTF-8
export LC_PAPER=en_US.UTF-8
export LC_NAME=en_US.UTF-8
export LC_ADDRESS=en_US.UTF-8
export LC_TELEPHONE=en_US.UTF-8
export LC_MEASUREMENT=en_US.UTF-8
export LC_IDENTIFICATION=en_US.UTF-8
export LC_ALL=

# Cisco Packet Tracer (only matters on machines that have it).
[[ -d /opt/pt ]] && export PT8HOME=/opt/pt

# XDG basics -- many tools fall back to broken defaults without these.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
