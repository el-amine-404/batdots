#!/usr/bin/env bash
# Parse the repo's pipe-delimited registry files (apps/**/<name>.txt, ...).
#
# The format every data list in this repo follows:
#   * one record per line, fields separated by '|'
#   * whitespace around each field is insignificant (it is trimmed)
#   * blank lines, and lines whose first non-space char is '#', are ignored
#   * the first line is conventionally a '# col | col | col' header comment
#
# The number and meaning of the columns is owned by each consumer; this
# library only normalises a file into clean records. Canonical use:
#
#   while IFS='|' read -r name url; do
#     ...
#   done < <(registry::stream "$file")
#
# Field values are expected to be single tokens (names, URLs, paths) with no
# embedded '|'. This holds for every registry in the repo.

# registry::require FILE -- return non-zero (logging an error) if FILE is absent.
# Callers decide whether to warn, skip, or escalate to log::fatal.
registry::require() {
  local file="${1:?registry::require requires a path}"
  [[ -f $file ]] && return 0
  log::error "Registry not found: $file"
  return 1
}

# registry::stream FILE -- emit every record with each field trimmed and the
# fields re-joined by a single '|'. Comments and blank lines are dropped.
registry::stream() {
  local file="${1:?registry::stream requires a path}"
  registry::require "$file" || return 1

  local line trimmed i record
  local -a fields
  while IFS= read -r line || [[ -n $line ]]; do
    trimmed=$(string::trim "$line")
    [[ -z $trimmed || $trimmed == '#'* ]] && continue

    IFS='|' read -ra fields <<< "$line"
    record=""
    for i in "${!fields[@]}"; do
      record+="$(string::trim "${fields[i]}")|"
    done
    printf '%s\n' "${record%|}"
  done < "$file"
}

# registry::field FILE [INDEX] -- print one column (1-based, default 1) of every
# record, one value per line. Handy for `--list` output and discovery.
registry::field() {
  local file="${1:?registry::field requires a path}"
  local index="${2:-1}"
  local -a fields
  while IFS='|' read -ra fields; do
    printf '%s\n' "${fields[$((index - 1))]:-}"
  done < <(registry::stream "$file")
}
