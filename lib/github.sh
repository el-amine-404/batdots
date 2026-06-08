#!/usr/bin/env bash
github::latest_tag() {
  local repo="${1:?github::latest_tag requires user/repo}"
  local prefix="${2:-}"
  git::latest_tag "https://github.com/${repo}.git" "$prefix"
}

github::sync_repo() {
  local url="${1:?github::sync_repo requires a URL}"
  local target="${2:?github::sync_repo requires a target directory}"
  local depth="${3:-1}"
  local branch="${4:-master}"

  if [[ ! $depth =~ ^[0-9]+$ ]]; then
    branch="$depth"
    depth=1
  fi

  local depth_args=()
  ((depth != 0)) && depth_args=(--depth "$depth")

  if [[ ! -d "${target}/.git" ]]; then
    log::info "Cloning ${url} -> ${target}"
    rm -rf "$target"
    mkdir -p "$target"
    git clone "${depth_args[@]}" -b "$branch" "$url" "$target"
    return $?
  fi

  local current
  current=$(git -C "$target" remote get-url origin 2> /dev/null || echo "")
  if [[ $current != "$url" ]]; then
    log::warn "Remote mismatch (${current} -> ${url})"
    git -C "$target" remote set-url origin "$url"
  fi

  git -C "$target" fetch "${depth_args[@]}" origin "$branch" --quiet

  local local_hash remote_hash
  local_hash=$(git -C "$target" rev-parse HEAD)
  remote_hash=$(git -C "$target" rev-parse "origin/$branch")
  if [[ $local_hash != "$remote_hash" || -n "$(git -C "$target" status --porcelain)" ]]; then
    log::info "Resyncing ${target}"
    git -C "$target" reset --hard "origin/$branch"
    git -C "$target" clean -fd
  fi
}
