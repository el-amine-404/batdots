# bashrc.d/10-history.sh -- history behavior.
# shellcheck shell=bash
# `histappend` is set in 00-shopt.sh.

# Don't store duplicate or whitespace-prefixed lines.
HISTCONTROL=ignoreboth:erasedups

# Sizes -- keep a generous in-memory buffer and on-disk history.
HISTSIZE=10000
HISTFILESIZE=20000

# Don't pollute history with trivial calls.
HISTIGNORE='ls:ll:la:l:cd:pwd:exit:clear:history:bg:fg:jobs'

# Timestamp every entry -- useful with `history` and required by some tools.
HISTTIMEFORMAT='%F %T  '

# Persist history immediately so multiple terminals stay in sync.
# (Appended to PROMPT_COMMAND, not overwriting it.)
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
