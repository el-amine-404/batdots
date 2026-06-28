#!/usr/bin/env bash
# scripts/maintenance/check-registries.sh -- Verify every URL referenced by the
# repo's registry files is still reachable. Exits non-zero if any URL is dead,
# so it can gate CI / a scheduled job.

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

declare -a CHECKREG_TARGETS=()
declare -a CHECKREG_DEAD_LIST=()
CHECKREG_OK=0
CHECKREG_DEAD=0

checkreg::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [REGISTRY_FILE ...]

Probe every http(s) URL found in the repo's pipe-delimited registry files
(apps/**/*.txt, config/**/*.txt). Plain URLs are fetched with curl; '*.git'
URLs are checked with 'git ls-remote'. Non-URL columns are ignored.

Options:
  -h, --help   Show this help message

With no REGISTRY_FILE, every registry under apps/ and config/ is scanned.
Exit status is non-zero when at least one URL is unreachable.
EOF
}

checkreg::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        checkreg::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        exit 1
        ;;
      *) CHECKREG_TARGETS+=("$1") ;;
    esac
    shift
  done
}

checkreg::all_registries() {
  find "${DOTFILES_ROOT}/apps" "${DOTFILES_ROOT}/config" -type f -name '*.txt' | sort
}

checkreg::resolve_targets() {
  ((${#CHECKREG_TARGETS[@]})) && return 0
  local file
  while IFS= read -r file; do CHECKREG_TARGETS+=("$file"); done < <(checkreg::all_registries)
}

checkreg::is_url() { [[ ${1:-} =~ ^https?:// ]]; }

checkreg::probe_url() {
  local url="$1"
  if [[ $url == *.git ]]; then
    if GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code -h "$url" > /dev/null 2>&1; then
      echo "200"
    else
      echo "git-err"
    fi
  else
    local code
    code=$(curl -sL -o /dev/null -w "%{http_code}" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --retry 2 --max-time 25 "$url" || true)
    echo "${code:-000}"
  fi
}

checkreg::check_url() {
  local url="$1" origin="$2" line_num="$3" col="$4"
  local status
  status=$(checkreg::probe_url "$url")

  local is_ok=0
  if [[ $status =~ ^(2[0-9]{2}|3[0-9]{2}|403|429)$ ]]; then
    is_ok=1
  fi

  if ((is_ok)); then
    CHECKREG_OK=$((CHECKREG_OK + 1))
    log::debug "OK   $origin:$line_num:$col -> $url ($status)"
  else
    CHECKREG_DEAD=$((CHECKREG_DEAD + 1))
    log::error "DEAD $origin:$line_num:$col -> $url ($status)"
    CHECKREG_DEAD_LIST+=("${origin}|${line_num}|${col}|${url}|${status}")
  fi
}

checkreg::check_file() {
  local file="$1"
  registry::require "$file" || return 0
  local origin="${file#"${DOTFILES_ROOT}/"}"
  local line_num=0
  local line trimmed i value
  local -a fields
  while IFS= read -r line || [[ -n $line ]]; do
    ((++line_num))
    trimmed=$(string::trim "$line")
    [[ -z $trimmed || $trimmed == '#'* ]] && continue

    IFS='|' read -ra fields <<< "$line"
    for i in "${!fields[@]}"; do
      value=$(string::trim "${fields[i]}")
      if checkreg::is_url "$value"; then
        local col=1
        local j
        for ((j = 0; j < i; j++)); do
          col=$((col + ${#fields[j]} + 1))
        done
        local raw_field="${fields[i]}"
        local trimmed_leading="${raw_field#"${raw_field%%[![:space:]]*}"}"
        local leading_ws_len=$((${#raw_field} - ${#trimmed_leading}))
        col=$((col + leading_ws_len))

        checkreg::check_url "$value" "$origin" "$line_num" "$col"
      fi
    done
  done < "$file"
}

checkreg::check_all() {
  local target
  for target in "${CHECKREG_TARGETS[@]}"; do
    checkreg::check_file "$target"
  done
}

checkreg::report() {
  log::info "Checked -- ${CHECKREG_OK} reachable, ${CHECKREG_DEAD} dead."
  if ((CHECKREG_DEAD > 0)); then
    echo "# Dead Registry URLs Detected"
    echo ""
    echo "The following dead URLs were found in the registry files:"
    echo ""
    echo "| File | Line | Column | Status | URL |"
    echo "| :--- | :--- | :--- | :--- | :--- |"
    local entry file line col url status
    for entry in "${CHECKREG_DEAD_LIST[@]}"; do
      IFS='|' read -r file line col url status <<< "$entry"
      echo "| ${file} | ${line} | ${col} | ${status} | ${url} |"
    done
  fi
  ((CHECKREG_DEAD == 0))
}

main() {
  checkreg::parse_args "$@"
  banner::print "registries" >&2
  checkreg::resolve_targets
  checkreg::check_all
  checkreg::report
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
