# bashrc.d/80-prompt.sh -- prompt.
# shellcheck shell=bash
# Prefer starship; otherwise fall back to a self-contained PS1 with
# git status + last-exit indicator.

if cmd::has starship; then
  eval "$(starship init bash)"
  return 0 2> /dev/null || true
fi

# -- fallback PS1 ------------------------------------------------------------

# Detect chroot once.
if [[ -z "${debian_chroot:-}" && -r /etc/debian_chroot ]]; then
  debian_chroot=$(< /etc/debian_chroot)
fi

# -- color escapes (\[ \] tells readline they're zero-width) -----------------
_RESET='\[\e[0m\]'
_BOLD='\[\e[1m\]'
_ITALIC='\[\e[3m\]'
_FG_GREEN='\[\e[32m\]'
_FG_BLUE='\[\e[34m\]'
_FG_CYAN='\[\e[96m\]'
_FG_OK='\[\e[92m\]'
_FG_BAD='\[\e[91m\]'

# Capture the previous command's exit *before* any other PROMPT_COMMAND step
# runs, otherwise __git_ps1 / history -a clobber $?.
_PS1_capture_status() { _PS1_LAST_STATUS=$?; }
PROMPT_COMMAND="_PS1_capture_status${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

_ps1_status_glyph() {
  if [[ "${_PS1_LAST_STATUS:-0}" -eq 0 ]]; then
    printf '\001\e[92m\002✔\001\e[0m\002'
  else
    printf '\001\e[91m\002✘ %s\001\e[0m\002' "${_PS1_LAST_STATUS}"
  fi
}

# Prompt char depends on uid.
if [[ $EUID -eq 0 ]]; then
  _PROMPT_CHAR='#'
else
  _PROMPT_CHAR='\$'
fi

# Use __git_ps1 if the prompt helper sourced in 30-completion.sh is present.
if declare -F __git_ps1 > /dev/null; then
  _GIT_FRAGMENT='$(__git_ps1 " -- (%s)")'
else
  _GIT_FRAGMENT=''
fi

PS1="\n${_BOLD}${_ITALIC}${_FG_CYAN}\W${_RESET}${_BOLD}${_ITALIC}${_GIT_FRAGMENT}\n\$(_ps1_status_glyph)${_RESET}${_BOLD}${_ITALIC} ${_PROMPT_CHAR} ${_RESET}"

# xterm/rxvt: also push user@host:cwd into the window title.
case "$TERM" in
  xterm* | rxvt*) PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1" ;;
esac

unset _RESET _BOLD _ITALIC _FG_GREEN _FG_BLUE _FG_CYAN _FG_OK _FG_BAD \
  _PROMPT_CHAR _GIT_FRAGMENT
