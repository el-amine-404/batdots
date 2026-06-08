#!/usr/bin/env bash
# scripts/user/tab-opener.sh -- Open URLs from one or more files in a browser safely.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

# Safety limits
MAX_TABS_BEFORE_PROMPT=15
MAX_TABS_TOTAL=50

# Trap Ctrl+C (SIGINT)
trap 'log::warn "Interrupted by user. Exiting..."; exit 130' SIGINT

tabs::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] <urls_file1> [urls_file2 ...]

Opens validated URLs from one or more files in the chosen browser.
Only http:// and https:// URLs are supported.

Options:
  -b, --browser BROWSER  Set browser (brave, firefox, chromium)
  -h, --help             Show this help message
EOF
}

tabs::is_valid_url() {
  local url="$1"
  # Simpler but robust regex for Bash [[ =~ ]]
  local regex='^https?://[[:alnum:]=%_.~/-]+(\?[[:alnum:]=%_.~&/-]+)?(#[[:alnum:]=%_.~&/-]+)?$'
  [[ $url =~ $regex ]]
}

tabs::get_urls_from_files() {
  local files=("$@")
  local urls=()
  local skipped_junk=0
  local skipped_dup=0
  declare -A seen

  for file in "${files[@]}"; do
    file::exists "$file" || exit 1

    # Check if file is binary to avoid "pdf explosion"
    if ! grep -qI . "$file" 2> /dev/null; then
      log::error "File appears to be binary or unreadable: $file"
      continue
    fi

    while IFS= read -r line || [[ -n $line ]]; do
      local trimmed
      trimmed=$(string::trim "$line")
      [[ -z $trimmed || $trimmed == "#"* ]] && continue

      # Process each word in the line
      for word in $trimmed; do
        if tabs::is_valid_url "$word"; then
          if [[ -z ${seen["$word"]:-} ]]; then
            urls+=("$word")
            seen["$word"]=1
          else
            ((skipped_dup++))
          fi
        else
          log::warn "Skipping invalid item: $word"
          ((skipped_junk++))
        fi
      done
    done < "$file"
  done

  if [[ $skipped_dup -gt 0 ]]; then
    log::info "Skipped $skipped_dup duplicate URL(s)."
  fi

  if [[ ${#urls[@]} -eq 0 ]]; then
    log::error "No valid http/https URLs found in the provided file(s)."
    return 1
  fi

  if [[ ${#urls[@]} -gt $MAX_TABS_TOTAL ]]; then
    log::error "Too many URLs (${#urls[@]}). Max allowed is $MAX_TABS_TOTAL."
    return 1
  fi

  if [[ ${#urls[@]} -gt $MAX_TABS_BEFORE_PROMPT ]]; then
    log::warn "You are about to open ${#urls[@]} tabs."
    if ! confirmation::seek "Are you sure you want to proceed?"; then
      log::info "Cancelled."
      return 1
    fi
  fi

  printf '%s\n' "${urls[@]}"
}

tabs::open() {
  local browser_type="$1"
  shift
  local urls=("$@")

  [[ ${#urls[@]} -eq 0 ]] && return 0

  local cmd=""
  case "$browser_type" in
    brave) cmd="brave-browser --incognito" ;;
    firefox) cmd="firefox --new-window" ;;
    chromium) cmd="chromium --incognito" ;;
    *) log::fatal "Unsupported browser type: $browser_type" ;;
  esac

  local bin
  bin=$(echo "$cmd" | awk '{print $1}')
  os::check_dependency "$bin" || log::fatal "$bin is not installed."

  banner::print "tabs"
  log::info "Opening ${#urls[@]} tabs in $browser_type..."
  $cmd "${urls[@]}" &
}

tabs::main() {
  local browser=""
  local urls_files=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b | --browser)
        shift
        browser="${1:?--browser requires an argument}"
        ;;
      -h | --help)
        tabs::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        log::info "Run with --help for usage."
        exit 1
        ;;
      *)
        urls_files+=("$1")
        ;;
    esac
    shift
  done

  if [[ ${#urls_files[@]} -eq 0 ]]; then
    log::error "No URL files provided."
    log::info "Run with --help for usage."
    exit 1
  fi

  local urls=()
  # Capture output from function - ensuring it only contains URLs
  # We use a temp file to avoid pipe failure issues with mapfile
  local tmp_urls
  tmp_urls=$(mktemp)
  # Ensure cleanup happens
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_urls'" EXIT

  if ! tabs::get_urls_from_files "${urls_files[@]}" > "$tmp_urls"; then
    exit 1
  fi

  mapfile -t urls < "$tmp_urls"

  if [[ ${#urls[@]} -eq 0 ]]; then
    exit 1
  fi

  if [[ -z $browser ]]; then
    log::info "No browser specified. Choose one:"
    local choices=("brave" "firefox" "chromium")
    local i=1
    for c in "${choices[@]}"; do
      echo "$i) $c"
      ((i++))
    done
    read -p "Choice [1-${#choices[@]}]: " -r choice_idx

    if [[ $choice_idx =~ ^[0-9]+$ ]] && ((choice_idx >= 1 && choice_idx <= ${#choices[@]})); then
      browser="${choices[$((choice_idx - 1))]}"
    else
      log::fatal "Invalid choice."
    fi
  fi

  tabs::open "$browser" "${urls[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  tabs::main "$@"
fi
sleep 0.2
