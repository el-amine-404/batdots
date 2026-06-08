# bashrc.d/20-dircolors.sh -- color support for ls/grep/ip.
# shellcheck shell=bash

if [[ -x /usr/bin/dircolors ]]; then
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# `ip` understands --color since iproute2 v4.something; safe on modern systems.
cmd::has ip && alias ip='ip --color=auto'
