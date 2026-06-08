#!/usr/bin/env bash
# scripts/user/bulk-rename.sh -- Sanitize and normalize file/dir names.

set -Eeuo pipefail

# Resolve the library path
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  # If script is symlinked, resolve to actual repo location
  BR_REAL_PATH="$(readlink -f -- "${BASH_SOURCE[0]:-$0}")"
  DOTFILES_ROOT="$(cd "$(dirname -- "$BR_REAL_PATH")/../.." && pwd)"
fi

LIB_DIR="${DOTFILES_ROOT}/lib"

if [[ -f "${LIB_DIR}/bash-utilities.sh" ]]; then
  source "${LIB_DIR}/bash-utilities.sh"
else
  echo "Error: Cannot find bash-utilities.sh at ${LIB_DIR}" >&2
  exit 1
fi

# Global State
BR_RECURSIVE=0
BR_TARGET_DIR=""
BR_INCLUDES=()
BR_EXCLUDES=()
BR_UNDO_FILE=""

# Stats
BR_STATS_PROCESSED=0
BR_STATS_RENAMED=0

br::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] <directory>

Sanitize and normalize all file and directory names.
Directories are converted to UPPERCASE, files to lowercase.

Options:
  -r, --recursive      Rename files and directories recursively.
  -n, --dry-run        Show what would be renamed without making changes.
  -i, --interactive    Confirm each rename before it happens.
  -I, --include PAT    Only process files matching glob pattern PAT (e.g. "*.jpg").
  -E, --exclude PAT    Skip files matching glob pattern PAT (e.g. "node_modules/*").
  -h, --help           Show this help message.
EOF
}

br::parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --recursive) BR_RECURSIVE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -i | --interactive) export INTERACTIVE_RENAME=1 ;;
      -I | --include)
        shift
        BR_INCLUDES+=("$1")
        ;;
      -E | --exclude)
        shift
        BR_EXCLUDES+=("$1")
        ;;
      -h | --help)
        br::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        exit 1
        ;;
      *) BR_TARGET_DIR="$1" ;;
    esac
    shift
  done

  if [[ -z "$BR_TARGET_DIR" ]]; then
    br::usage
    exit 1
  fi

  if [[ ! -d "$BR_TARGET_DIR" ]]; then
    log::error "Target is not a directory: $BR_TARGET_DIR"
    exit 1
  fi

  return 0
}

br::setup_undo() {
  [[ ${DRY_RUN:-0} == 1 ]] && return 0

  BR_UNDO_FILE=".bulk-rename-undo-$(date +%Y%m%d_%H%M%S).sh"
  export UNDO_SCRIPT_PATH="${BR_TARGET_DIR}/${BR_UNDO_FILE}"

  printf '#!/usr/bin/env bash\n# Undo script for bulk-rename run on %s\n' "$(date)" > "$UNDO_SCRIPT_PATH"
  chmod +x "$UNDO_SCRIPT_PATH"
}

# Renames are applied deepest-first (find -depth), and each reverse-mv is appended
# in that order. To undo correctly a renamed parent dir must be restored BEFORE the
# children referenced beneath it -- i.e. the inverse mvs must replay in reverse of
# application order. So reverse the body (keeping the 2-line header) after the run.
br::finalize_undo() {
  [[ ${DRY_RUN:-0} == 1 || -z ${UNDO_SCRIPT_PATH:-} || ! -f $UNDO_SCRIPT_PATH ]] && return 0
  local tmp
  tmp=$(mktemp)
  {
    head -n 2 -- "$UNDO_SCRIPT_PATH"
    tail -n +3 -- "$UNDO_SCRIPT_PATH" | tac
  } > "$tmp"
  mv -- "$tmp" "$UNDO_SCRIPT_PATH"
  chmod +x "$UNDO_SCRIPT_PATH"
}

br::print_summary() {
  local elapsed="$1"
  echo
  log::info "--- Operation Summary ---"
  log::info "Processed: $BR_STATS_PROCESSED"
  log::info "Renamed:   $BR_STATS_RENAMED"
  log::info "Time:      ${elapsed}s"
  if [[ $BR_STATS_RENAMED -gt 0 ]]; then
    [[ -n "$BR_UNDO_FILE" ]] && log::warn "Undo script created: $BR_UNDO_FILE (run it to revert)"
  else
    # Nothing changed (every name was already normalized). Drop the empty undo
    # file we pre-created so it can't be mistaken for a failed/lost run.
    [[ -n "${UNDO_SCRIPT_PATH:-}" && -f "$UNDO_SCRIPT_PATH" ]] && rm -f "$UNDO_SCRIPT_PATH"
    log::info "Nothing to rename -- all names already normalized."
  fi
}

br::rename_item() {
  local item="$1"
  if [[ -d "$item" ]]; then
    file::sanitize_and_uppercase_name "$item"
  else
    file::sanitize_and_lowercase_name "$item"
  fi
}

br::process_directory() {
  local target="$1"
  local start=$SECONDS

  # Build find command
  local find_args=("$target" -mindepth 1 -depth)
  [[ $BR_RECURSIVE -eq 0 ]] && find_args+=(-maxdepth 1)

  if ((${#BR_INCLUDES[@]} > 0)); then
    find_args+=("(")
    for i in "${!BR_INCLUDES[@]}"; do
      ((i > 0)) && find_args+=("-o")
      find_args+=("-name" "${BR_INCLUDES[i]}")
    done
    find_args+=(")")
  fi

  for pattern in "${BR_EXCLUDES[@]}"; do
    find_args+=("-not" "-path" "$pattern")
  done

  log::info "Scanning directory contents..."
  local temp_list
  temp_list=$(mktemp)
  find "${find_args[@]}" -print0 > "$temp_list"

  local total_items
  total_items=$(tr -cd '\0' < "$temp_list" | wc -c)
  # Exclude the undo script from the count if it was created in the target dir
  if [[ -n "$BR_UNDO_FILE" ]]; then
    ((total_items--)) || :
  fi
  log::info "Found $total_items items. Processing..."

  while IFS= read -r -d '' item; do
    [[ "$item" == *"$BR_UNDO_FILE" ]] && continue

    ((BR_STATS_PROCESSED++)) || :

    # Update progress line (every 5 items or at the end to keep it smooth but low overhead)
    if [[ -t 2 ]] && { ((BR_STATS_PROCESSED % 5 == 0)) || [[ $BR_STATS_PROCESSED -eq $total_items ]]; }; then
      printf "\r${FG_YELLOW}» Progress: [%d/%d]${RESET}" "$BR_STATS_PROCESSED" "$total_items" >&2
    fi

    if br::rename_item "$item"; then
      ((BR_STATS_RENAMED++)) || :
    fi
  done < "$temp_list"

  rm -f "$temp_list"
  [[ $BR_STATS_RENAMED -gt 0 ]] && br::finalize_undo
  br::print_summary "$((SECONDS - start))"
}

br::main() {
  br::parse_arguments "$@"
  banner::print "bulk rename"
  br::setup_undo
  br::process_directory "$BR_TARGET_DIR"
}

br::main "$@"
