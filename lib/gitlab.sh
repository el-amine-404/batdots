#!/usr/bin/env bash
gitlab::latest_tag() {
  local repo="${1:?gitlab::latest_tag requires user/repo}"
  local prefix="${2:-}"
  local server="${3:-gitlab.com}"
  git::latest_tag "https://${server}/${repo}.git" "$prefix"
}
