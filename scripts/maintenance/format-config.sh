#!/usr/bin/env bash
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"
# Canonicalize the data files under config/package-managers/.
#
# Rules applied (in order, per file):
#   1. Strip trailing whitespace on every line.
#   2. Normalize "key=value" -- drop spaces around the first `=`.
#   3. Drop "decorative" comment lines (a # with nothing or just dashes/===).
#      Section-label comments like "# GStreamer" stay -- they're navigation aids.
#   4. Collapse runs of 2+ blank lines into a single blank line.
#   5. Ensure exactly one trailing newline.
#
# Usage:
#   ./scripts/maintenance/format-config.sh           # format in place
#   ./scripts/maintenance/format-config.sh --check   # exit non-zero if anything would change
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

shopt -s nullglob
files=("${DOTFILES_ROOT}/config/package-managers/"*.conf)
shopt -u nullglob

format_one() {
  awk '
    # Drop purely decorative comments -- bare #, dashes, equals, or runs of those.
    /^[[:space:]]*#[[:space:]]*[-=#*[:space:]]*$/ { next }

    # Normalize key = value -> key=value (only the first = on the line).
    {
      sub(/[[:space:]]+$/, "")          # 1. trailing whitespace
      if ($0 ~ /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=/) {
        # Split on the FIRST = only.
        n = index($0, "=")
        key = substr($0, 1, n - 1)
        val = substr($0, n + 1)
        sub(/[[:space:]]+$/, "", key)
        sub(/^[[:space:]]+/, "", val)
        $0 = key "=" val
      }
    }

    # Collapse blank-line runs to at most one blank line.
    /^$/ { if (blank++) next; print; next }
    { blank = 0; print }
  ' "$1"
}

dirty=0
for f in "${files[@]}"; do
  formatted=$(format_one "$f")
  # Always end with exactly one newline.
  formatted="${formatted%$'\n'}"$'\n'
  if [[ "$formatted" != "$(cat "$f")"$'\n' && "$formatted" != "$(cat "$f")" ]]; then
    if $CHECK_ONLY; then
      echo "would reformat: ${f#"$DOTFILES_ROOT"/}" >&2
      dirty=1
    else
      printf '%s' "$formatted" > "$f"
      echo "formatted: ${f#"$DOTFILES_ROOT"/}"
    fi
  fi
done

if $CHECK_ONLY && ((dirty)); then
  echo
  echo "config files are not canonicalized -- run scripts/maintenance/format-config.sh" >&2
  exit 1
fi
