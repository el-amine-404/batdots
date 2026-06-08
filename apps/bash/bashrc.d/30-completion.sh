# bashrc.d/30-completion.sh -- bash + git completion.
# shellcheck shell=bash

# System bash-completion (only if not in posix mode).
if ! shopt -oq posix; then
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
  elif [[ -r /etc/bash_completion ]]; then
    source /etc/bash_completion
  fi
fi

# git-completion + git-prompt -- try the common locations.
{
  for _gc in \
    "$HOME/.local/share/git-core/git-completion.bash" \
    /usr/share/bash-completion/completions/git \
    /usr/lib/git-core/git-completion.bash; do
    [[ -r "$_gc" ]] && {
      source "$_gc"
      break
    }
  done
} || true

{
  for _gp in \
    /usr/lib/git-core/git-sh-prompt \
    /usr/share/git-core/contrib/completion/git-prompt.sh \
    "$HOME/.local/share/git-core/git-prompt.sh"; do
    [[ -r "$_gp" ]] && {
      source "$_gp"
      break
    }
  done
} || true

unset _gc _gp

# git-prompt knobs (used by 80-prompt.sh fallback).
export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM="auto verbose name"
export GIT_PS1_SHOWCOLORHINTS=1
