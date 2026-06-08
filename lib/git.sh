#!/usr/bin/env bash
# Resolve the highest-version tag of a git repo via `git ls-remote --tags`.
# Bypasses host APIs (rate limits, maintainer-controlled "latest" labels).
# Works for any git server that speaks HTTPS.
#
# Usage: tag=$(git::latest_tag URL [PREFIX])
#   PREFIX is stripped before sorting (e.g. "nasm-" or "gs"). A leading 'v' is
#   always stripped from the stripped string.
#
# Sorting:
#   1. Pre-release tags (rc/beta/alpha/pre/...) are filtered out.
#   2. Dotted versions (1.2.3) outrank opaque packed numerics (10070).
#   3. Within each tier `sort -V` decides the winner.
#
# Returns: the raw upstream tag (e.g. "nasm-3.01"). Caller is responsible for
# any prefix stripping it needs for storage.
git::latest_tag() {
  local url="${1:?git::latest_tag requires a URL}"
  local prefix="${2:-}"

  local raw_tags=""
  local attempt=1
  local max_attempts=3

  while ((attempt <= max_attempts)); do
    raw_tags=$(timeout 30s git ls-remote --tags --refs "$url" 2> /dev/null \
      | awk -F/ '{print $NF}') && [[ -n $raw_tags ]] && break

    log::debug "git::latest_tag: attempt ${attempt} failed for $url, retrying..."
    ((attempt++))
    sleep 1
  done

  if [[ -z $raw_tags ]]; then
    log::debug "git::latest_tag: no tags found for $url after ${max_attempts} attempts"
    return 1
  fi

  local version_chars='^[0-9][0-9._-]*$'

  local tag
  tag=$(echo "$raw_tags" \
    | grep -vEi '(rc|beta|alpha|pre|verified|master|latest|dev|snapshot|test|debug|draft)' \
    | while read -r t; do
      local stripped="$t"
      if [[ -n $prefix ]]; then
        [[ $t == "$prefix"* ]] || continue
        stripped="${t#"$prefix"}"
      fi
      stripped="${stripped#[vV]}"
      [[ $stripped =~ $version_chars ]] || continue

      # Score: dotted (2) > packed (1). Sortable form normalizes hyphens.
      local score sortable
      if [[ $stripped == *.* ]]; then
        score=2
        sortable="${stripped//-/.}"
      else
        score=1
        sortable="$stripped"
      fi
      printf '%d|%s|%s\n' "$score" "$sortable" "$t"
    done \
    | sort -t'|' -k1,1n -k2,2V \
    | tail -n 1 \
    | cut -d'|' -f3)

  if [[ -z $tag ]]; then
    log::debug "git::latest_tag: no valid tags for $url (prefix='${prefix}')"
    return 1
  fi
  printf '%s\n' "$tag"
}
