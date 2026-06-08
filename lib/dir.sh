#!/usr/bin/env bash
dir::create() {
  local dir="${1:-}"
  [[ -z $dir ]] && {
    log::error "dir::create requires a path"
    return 1
  }
  [[ -d $dir ]] || mkdir -p -- "$dir"
}

dir::remove() {
  local dir="${1:-}"
  [[ -z $dir ]] && {
    log::error "dir::remove requires a path"
    return 1
  }
  file::is_directory "$dir" || return 1
  rm -rd -- "$dir"
}

dir::ensure() {
  [[ -d "${1:-}" ]] || mkdir -p -- "${1:-}"
}

dir::move() {
  local src="${1:-}" dst="${2:-}"
  [[ -z $src || -z $dst ]] && {
    log::error "dir::move requires SRC DST"
    return 1
  }
  [[ -d $src ]] || {
    log::error "source dir missing: $src"
    return 1
  }
  mv -v --backup=t -- "$src" "$dst"
}
