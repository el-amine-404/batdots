#!/usr/bin/env bash
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"
# Refresh every PREFIX_VERSION line in config/versions.conf from upstream.
#
# Strategy is type-aware (github / gitlab / bitbucket / googlestorage / git /
# fixed) and dispatched in lib/source.sh. Components for which the fetch fails
# keep their cached value untouched; the script only rewrites lines that need
# to change.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=/dev/null
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

CONF="${DOTFILES_ROOT}/config/versions.conf"

ALL_COMPONENTS=(
  "${MEDIA_STACK_COMPONENTS[@]}"
  "${FONT_COMPONENTS[@]}"
  "${TOOL_COMPONENTS[@]}"
)

log::info "Fetching latest versions for ${#ALL_COMPONENTS[@]} components..."

updated=0
failed=0

for component in "${ALL_COMPONENTS[@]}"; do
  current_var="${component}_VERSION"
  current="${!current_var:-}"

  latest=$(source::fetch_latest "$component" 2> /dev/null) || latest=""

  if [[ -z $latest ]]; then
    if [[ -n $current ]]; then
      log::warn "${component}: fetch failed -- keeping cached ${current}"
    else
      log::error "${component}: fetch failed and no cached version exists"
      failed=$((failed + 1))
    fi
    continue
  fi

  if [[ $current == "$latest" ]]; then
    log::info "${component}: ${latest} (no change)"
    continue
  fi

  # awk in-place: only the exact PREFIX_VERSION= line is replaced. Safer than
  # sed when 'latest' contains regex/sed-special characters.
  tmp=$(mktemp)
  awk -v key="${component}_VERSION" -v val="$latest" '
    BEGIN { pat = "^" key "=" }
    $0 ~ pat { print key "=\"" val "\""; next }
                 { print }
  ' "$CONF" > "$tmp" && mv "$tmp" "$CONF"

  log::info "${component}: ${current:-unset} -> ${latest}"
  updated=$((updated + 1))
done

echo ""
log::info "Done: ${updated} updated, ${failed} failed"
