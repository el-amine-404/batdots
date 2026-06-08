#!/usr/bin/env bash
# scripts/user/extract-links.sh -- Print the unique absolute http(s) links found
# in one or more web pages or local HTML files, using lynx as the renderer.
#
# Targets may be passed as arguments or, when none are given, read one-per-line
# from stdin (so it composes in pipelines). Links are emitted to stdout, sorted
# and de-duplicated; diagnostics go to stderr, keeping stdout clean for piping.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

LINKS_TARGETS=()

links::usage() {
  cat << EOF
Usage: $(basename "$0") [URL|FILE]...

Extracts the unique absolute http(s) links from each web page or local HTML
file. With no arguments, reads newline-separated targets from stdin.

Examples:
  $(basename "$0") https://example.com
  $(basename "$0") page1.html https://example.org
  printf '%s\n' https://a.com https://b.com | $(basename "$0")

Options:
  -h, --help    Show this help message
EOF
}

links::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        links::usage
        exit 0
        ;;
      --)
        shift
        LINKS_TARGETS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        links::usage >&2
        exit 2
        ;;
      *) LINKS_TARGETS+=("$1") ;;
    esac
    shift
  done

  [[ ${#LINKS_TARGETS[@]} -gt 0 ]] && return 0

  # No arguments: pull targets from stdin unless it's an interactive terminal.
  if [[ -t 0 ]]; then
    log::error "No URL or file given"
    links::usage >&2
    exit 2
  fi
  local line
  while IFS= read -r line; do
    line=$(string::trim "$line")
    [[ -n $line ]] && LINKS_TARGETS+=("$line")
  done

  [[ ${#LINKS_TARGETS[@]} -gt 0 ]] || log::fatal "No targets given (stdin was empty)"
}

links::require_deps() {
  command::exists lynx \
    || log::fatal "lynx not found -- install the 'lynx' package (run bootstrap to provision it)"
}

# Emit absolute http(s) links from a single target. lynx errors are silenced and
# a link-free page (grep exits 1) is not treated as a failure.
links::from_target() {
  lynx -listonly -nonumbers -display_charset=utf-8 -dump "$1" 2> /dev/null \
    | grep '^http' || true
}

main() {
  banner::print "extract-links" >&2
  links::parse_args "$@"
  links::require_deps

  local target
  for target in "${LINKS_TARGETS[@]}"; do
    links::from_target "$target"
  done | sort -u
}

main "$@"
