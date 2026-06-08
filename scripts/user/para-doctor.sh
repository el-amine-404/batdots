#!/usr/bin/env bash
# scripts/user/para-doctor.sh -- Audit-only health check for the PARA file tree
# (DOTFILES_PARA_ROOT, e.g. ~/Documents). Reports drift that turns a tidy archive
# into a mess over time: missing structure, clutter at the root, an inbox that has
# stopped being transient, oversized files, and empty-dir litter. It NEVER changes
# anything -- fix things yourself, or with the dedicated tidy/optimize scripts.
# Mirrors bin/doctor.sh: per-check ok/warn results, --json, non-zero exit on drift.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

trap 'log::warn "Interrupted."; exit 130' SIGINT

PARA_ROOT="${DOTFILES_PARA_ROOT:?DOTFILES_PARA_ROOT must be set in local/env.sh (e.g. \$HOME/Documents)}"
STALE_DAYS="${DOTFILES_PARA_INBOX_STALE_DAYS:-30}"
LARGE_MB="${DOTFILES_PARA_LARGE_FILE_MB:-100}"
LIST_CAP=15 # how many offending items to print per check

# The canonical PARA top-level dirs. Anything else at the root is clutter.
PARA_DIRS=(0_INBOX 1_PROJECTS 2_AREAS 3_RESOURCES 4_ARCHIVES)

# Build/VCS/IDE dirs are self-managed noise -- skip them in litter scans so the
# signal (genuine drift in your own files) isn't drowned by project internals.
PARA_PRUNE=(.git .idea .vscode node_modules target build dist .gradle .venv __pycache__ .angular .mvn)

declare -A PARA_RESULTS

FMT_OK="[  OK  ]"
FMT_WARN="[ WARN ]"

para::print_help() {
  cat << EOF
Usage: $(basename -- "$0") [--json] [-h]

Audit-only PARA health check for DOTFILES_PARA_ROOT (${PARA_ROOT}).
Reports drift; never modifies anything.

Options:
  --json    Emit a machine-readable summary (for timers/dashboards)
  --empty   Also scan for empty directories (noisy; off by default)
  -h        Show this help

Tunables (local/env.sh):
  DOTFILES_PARA_ROOT              PARA root to audit (required)
  DOTFILES_PARA_INBOX_STALE_DAYS  inbox item is "stale" past this age (default 30)
  DOTFILES_PARA_LARGE_FILE_MB     flag files at/above this size (default 100)
EOF
}

para::human() { numfmt --to=iec --suffix=B "${1:-0}" 2> /dev/null || printf '%sB' "${1:-0}"; }

# Emit (NUL-separated) the find prune expression for PARA_PRUNE, ready to splice
# before the real match: find ROOT <prune> -o <your -type ... -print>.
para::prune_expr() {
  local args=('(' -type d '(') first=1 n
  for n in "${PARA_PRUNE[@]}"; do
    ((first)) || args+=(-o)
    args+=(-name "$n")
    first=0
  done
  args+=(')' -prune ')' -o)
  printf '%s\0' "${args[@]}"
}

# True if DIR sits inside a git working tree under the PARA root -- such dirs are
# managed by their repo, not by you, so their empties aren't real litter.
para::in_git_repo() {
  local d="$1"
  while [[ $d == "$PARA_ROOT"/* ]]; do
    [[ -e "$d/.git" ]] && return 0
    d=$(dirname -- "$d")
  done
  return 1
}

# Print up to LIST_CAP lines from stdin, then a "(+N more)" note if truncated.
para::head_capped() {
  local total="$1" shown=0 line
  while IFS= read -r line; do
    ((shown < LIST_CAP)) || break
    printf '         - %s\n' "$line"
    shown=$((shown + 1))
  done
  ((total > LIST_CAP)) && printf '         ... (+%d more)\n' "$((total - LIST_CAP))"
  return 0
}

# -- check: structure --------------------------------------------------------
para::check_structure() {
  local missing=() d
  for d in "${PARA_DIRS[@]}"; do
    [[ -d "${PARA_ROOT}/${d}" ]] || missing+=("$d")
  done
  if ((${#missing[@]} == 0)); then
    PARA_RESULTS[structure]="ok"
    printf '%s structure: all %d PARA dirs present\n' "$FMT_OK" "${#PARA_DIRS[@]}"
    return 0
  fi
  PARA_RESULTS[structure]="warn"
  printf '%s structure: missing %d dir(s)\n' "$FMT_WARN" "${#missing[@]}"
  printf '         - %s\n' "${missing[@]}"
  return 1
}

# -- check: root clutter -----------------------------------------------------
# Loose files and non-PARA directories sitting at the root instead of inside a
# PARA bucket. (server-potato.txt, test/, ai/ ... are the usual suspects.)
para::check_root_clutter() {
  local pat
  pat=$(
    IFS='|'
    printf '%s' "${PARA_DIRS[*]}"
  )
  local items=()
  mapfile -t items < <(
    find "$PARA_ROOT" -mindepth 1 -maxdepth 1 \
      \( -type f -o -type d \) -printf '%y %f\n' 2> /dev/null \
      | grep -vE "^d (${pat})$" \
      | grep -v '^[df] \.' \
      | sort
  )
  if ((${#items[@]} == 0)); then
    PARA_RESULTS[root_clutter]="ok"
    printf '%s root: clean -- only PARA dirs at the top level\n' "$FMT_OK"
    return 0
  fi
  PARA_RESULTS[root_clutter]="warn"
  printf '%s root: %d stray item(s) at the PARA root -- move into a bucket\n' "$FMT_WARN" "${#items[@]}"
  printf '%s\n' "${items[@]}" | para::head_capped "${#items[@]}"
  return 1
}

# -- check: stale inbox ------------------------------------------------------
# 0_INBOX is meant to be transient: things land, get processed, leave. Items
# older than STALE_DAYS mean the inbox has become a dumping ground.
para::check_inbox_stale() {
  local inbox="${PARA_ROOT}/0_INBOX"
  [[ -d $inbox ]] || {
    PARA_RESULTS[inbox_stale]="ok"
    printf '%s inbox: no 0_INBOX dir -- nothing to age out\n' "$FMT_OK"
    return 0
  }
  local stale=()
  mapfile -t stale < <(
    find "$inbox" -mindepth 1 -maxdepth 1 -mtime "+${STALE_DAYS}" \
      -printf '%TY-%Tm-%Td  %f\n' 2> /dev/null | sort
  )
  if ((${#stale[@]} == 0)); then
    PARA_RESULTS[inbox_stale]="ok"
    printf '%s inbox: nothing older than %d days\n' "$FMT_OK" "$STALE_DAYS"
    return 0
  fi
  PARA_RESULTS[inbox_stale]="warn"
  printf '%s inbox: %d item(s) sitting >%d days (oldest first) -- process or file them\n' \
    "$FMT_WARN" "${#stale[@]}" "$STALE_DAYS"
  printf '%s\n' "${stale[@]}" | para::head_capped "${#stale[@]}"
  return 1
}

# -- check: large files ------------------------------------------------------
para::check_large_files() {
  local prune=()
  mapfile -d '' prune < <(para::prune_expr)
  local rows=()
  mapfile -t rows < <(
    find "$PARA_ROOT" "${prune[@]}" -type f -size "+${LARGE_MB}M" -printf '%s\t%p\n' 2> /dev/null \
      | sort -rn
  )
  if ((${#rows[@]} == 0)); then
    PARA_RESULTS[large_files]="ok"
    printf '%s size: no files at/above %dMB\n' "$FMT_OK" "$LARGE_MB"
    return 0
  fi
  PARA_RESULTS[large_files]="warn"
  printf '%s size: %d file(s) at/above %dMB -- archive, compress, or delete\n' \
    "$FMT_WARN" "${#rows[@]}" "$LARGE_MB"
  local r bytes path
  printf '%s\n' "${rows[@]}" | {
    local n=0
    while IFS=$'\t' read -r bytes path; do
      ((n < LIST_CAP)) || break
      printf '         - %8s  %s\n' "$(para::human "$bytes")" "${path#"$PARA_ROOT"/}"
      n=$((n + 1))
    done
    ((${#rows[@]} > LIST_CAP)) && printf '         ... (+%d more)\n' "$((${#rows[@]} - LIST_CAP))"
  }
  return 1
}

# -- check: empty dirs -------------------------------------------------------
para::check_empty_dirs() {
  local prune=()
  mapfile -d '' prune < <(para::prune_expr)
  local candidates=() dirs=() d
  mapfile -t candidates < <(
    find "$PARA_ROOT" -mindepth 1 "${prune[@]}" -type d -empty -print 2> /dev/null | sort
  )
  # Keep only genuine organizational empties: skip hidden dirs (.git/.GIT/.trash/...),
  # the self-managed 1_PROJECTS subtree, and anything inside a git working tree.
  for d in "${candidates[@]}"; do
    [[ $d == *"/."* ]] && continue
    [[ $d == "$PARA_ROOT/1_PROJECTS/"* ]] && continue
    para::in_git_repo "$d" && continue
    dirs+=("$d")
  done
  if ((${#dirs[@]} == 0)); then
    PARA_RESULTS[empty_dirs]="ok"
    printf '%s empty: no empty directories\n' "$FMT_OK"
    return 0
  fi
  PARA_RESULTS[empty_dirs]="warn"
  printf '%s empty: %d empty director(ies) -- prune the litter\n' "$FMT_WARN" "${#dirs[@]}"
  printf '%s\n' "${dirs[@]/#"$PARA_ROOT"\//}" | para::head_capped "${#dirs[@]}"
  return 1
}

para::emit_json() {
  local exit_code="$1" first=1 k
  printf '{"para_root":"%s","exit":%d,"results":{' "$PARA_ROOT" "$exit_code"
  for k in "${!PARA_RESULTS[@]}"; do
    ((first)) || printf ','
    printf '"%s":"%s"' "$k" "${PARA_RESULTS[$k]}"
    first=0
  done
  printf '}}\n'
}

main() {
  local emit_json=0 scan_empty=0 arg
  for arg in "$@"; do
    case "$arg" in
      -h | --help)
        para::print_help
        exit 0
        ;;
      --json) emit_json=1 ;;
      --empty) scan_empty=1 ;;
      *)
        para::print_help >&2
        exit 1
        ;;
    esac
  done

  [[ -d $PARA_ROOT ]] || log::fatal "DOTFILES_PARA_ROOT is not a directory: ${PARA_ROOT}"

  [[ $emit_json == 0 ]] && banner::print "para-doctor"

  local exit_code=0
  para::check_structure || exit_code=1
  para::check_root_clutter || exit_code=1
  para::check_inbox_stale || exit_code=1
  para::check_large_files || exit_code=1
  ((scan_empty)) && { para::check_empty_dirs || exit_code=1; }

  if [[ $emit_json == 1 ]]; then
    para::emit_json "$exit_code"
  elif [[ $exit_code -eq 0 ]]; then
    log::info "PARA tree is healthy."
  else
    log::warn "PARA drift detected -- see warnings above."
  fi
  exit "$exit_code"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
