#!/usr/bin/env bash
# Visual headers used by bin/bootstrap.sh and the task scripts.
# Pure printf + ANSI. no figlet, no chafa, no external tools required.

banner::splash() {
  local title="${1:-${DOTFILES_PROJECT_NAME:?DOTFILES_PROJECT_NAME is not set}}"
  local tagline="${2:-${DOTFILES_PROJECT_DESCRIPTION:?DOTFILES_PROJECT_DESCRIPTION is not set}}"

  if [[ ! -t 2 ]]; then
    printf '\n== %s -- %s ==\n\n' "$title" "$tagline" >&2
    return 0
  fi

  # Chars from CP437/Unicode block-fill set,
  # rendered everywhere a UTF-8 locale is in use
  # On a system without UTF-8 they show as `?`
  # ASCII bat by Joan Stark, see CREDITS.md.
  #
  # shellcheck disable=SC2016
  {
    local bat="$FG_RED"
    local R="$RESET"

    printf '\n' >&2
    printf '%s    _   ,_,   _%s\n' \
      "$bat" "$R" >&2
    printf '%s   / `'\''=) (='\''` \\%s     %s%s%s\n' \
      "$bat" "$R" \
      "$BOLD$FG_WHITE" "$title" "$R" >&2
    printf '%s  /.-.-.\\ /.-.-.\\%s     %s%s%s\n' \
      "$bat" "$R" \
      "$DIM" "$tagline" "$R" >&2
    printf '%s  `      "      `%s\n' \
      "$bat" "$R" >&2
    printf '\n' >&2
  }
}

# small per-task heading. Used by every task script to mark the start
banner::print() {
  local title="${1:?banner::print requires a title}"
  if command -v figlet &> /dev/null; then
    figlet "$title" -f slant
  else
    printf '\n%s» %s%s\n' "$BOLD$FG_CYAN" "$title" "$RESET" >&2
  fi
}
