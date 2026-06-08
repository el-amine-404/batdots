#!/usr/bin/env bash
# String helpers used across the codebase.

string::trim() {
  local s="$*"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Echo a non-existing path next to $1 by appending _1, _2, ... before any
# extension. Used to avoid clobbering existing files in archive/merge flows.
# Examples:
#   string::next_available_path /tmp/out.tar.xz   returns  /tmp/out_1.tar.xz   (if taken)
#   string::next_available_path /tmp/photos       returns  /tmp/photos_1
string::next_available_path() {
  local path="${1:?string::next_available_path requires a path}"
  [[ ! -e $path ]] && {
    printf '%s' "$path"
    return 0
  }

  local dir name base ext
  dir="$(dirname -- "$path")"
  name="$(basename -- "$path")"
  if [[ $name == *.* ]]; then
    base="${name%%.*}"
    ext=".${name#*.}"
  else
    base="$name"
    ext=""
  fi

  local i=1
  local candidate
  while :; do
    candidate="${dir}/${base}_${i}${ext}"
    [[ ! -e $candidate ]] && {
      printf '%s' "$candidate"
      return 0
    }
    ((i++))
  done
}
