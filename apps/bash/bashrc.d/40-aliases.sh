# bashrc.d/40-aliases.sh -- interactive aliases.
# shellcheck shell=bash
# Note: anything that needs runtime command substitution is a function in
# 50-functions.sh -- aliases that wrap $(...) inside double quotes evaluate
# at *definition* time, which is almost never what you want.

# -- ls family ---------------------------------------------------------------
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'

# -- notifier for long-running commands: `sleep 10; alert` -------------------
# shellcheck disable=SC2142
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# -- productivity ------------------------------------------------------------
alias path='echo -e "${PATH//:/\\n}"'
alias now='date +"%T"'
alias nowtime='now'
alias nowdate='date +"%F"'
# `cat file | c` -> copy to system clipboard, no trailing newline.
alias c='tr -d "\n" | xclip -selection clipboard'

# -- network -----------------------------------------------------------------
alias ipconfig='ip -c --brief addr show'

# -- docker ------------------------------------------------------------------
# Use xargs -r so each alias is a no-op when there's nothing to act on.
alias di='docker images'
alias dr='docker ps -aq | xargs -r docker rm'
alias ds='docker ps -q  | xargs -r docker stop'
alias dri='docker images -q | xargs -r docker rmi'
alias dsr='ds && dr'
alias dcup='docker compose up'

# Pretty `docker ps` / `docker ps -a` -- see dps()/dpsa() in 50-functions.sh.

# -- git author swap -- see git-author() in 50-functions.sh -------------------
# Personal credentials live in local/env.sh (gitignored), not here.
