# bashrc.d/00-shopt.sh -- shell options for interactive shells.
# shellcheck shell=bash

shell::shopt autocd                  # `dirname` alone enters the directory.
shell::shopt cdspell                 # Auto-correct minor cd typos.
shell::shopt dirspell                # Auto-correct minor dir typos in completion.
shell::shopt cdable_vars             # `cd FOO` works if $FOO is a directory.
shell::shopt checkwinsize            # Refresh LINES/COLUMNS after each command.
shell::shopt histappend              # Append to history, don't overwrite it.
shell::shopt cmdhist                 # Multi-line commands collapse to one history entry.
shell::shopt no_empty_cmd_completion # Don't complete on an empty line.
