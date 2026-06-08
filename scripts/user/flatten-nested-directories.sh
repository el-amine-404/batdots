#!/usr/bin/env bash
# scripts/user/flatten-nested-directories.sh -- Move every nested file up into a
# target directory, then optionally prune the emptied folders.
#
# Safety:
#   * Operates on an explicit target (default: current dir); validates it and
#     refuses the filesystem root.
#   * Confirms before moving (skip with --yes); --dry-run previews only.
#   * Never overwrites: colliding names become 'file-1.ext', 'file-2.ext', ....
#   * Skips symlinks (-type f) and stays on one filesystem (-xdev), so it can't
#     relocate link targets or wander into other mounts.
#   * Writes a timestamped, runnable undo script that recreates the original
#     directories (mkdir -p) and moves each file back (mv -n, never clobbering).
#
# Speed:
#   * Pure parameter expansion instead of per-file basename/dirname processes.
#   * In-memory claimed-name map avoids repeated stat() storms on collisions.
#   * -xdev keeps every move a cheap same-filesystem rename, never a copy.
#   * Undo lines stream through a single open file descriptor.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

FND_TARGET="."
FND_ASSUME_YES=0
FND_CLEAN_EMPTY=0
FND_MOVED=0
FND_UNDO_FILE=""
FND_DST=""
declare -a FND_FILES=()
declare -A FND_CLAIMED=()

fnd::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [DIR]

Moves every file nested below DIR (default: current directory) up into DIR
itself, leaving DIR's own top-level files untouched. Name collisions are
resolved with a numeric suffix; nothing is ever overwritten.

A timestamped undo script (DIR/flatten-undo-<date>.sh) is written; run it to
rebuild the original directory tree and move every file back.

Options:
  -y, --yes          Don't prompt for confirmation
  -n, --dry-run      Show what would move without touching anything
  -c, --clean-empty  Remove directories left empty after flattening
  -h, --help         Show this help message
EOF
}

fnd::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y | --yes) FND_ASSUME_YES=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -c | --clean-empty) FND_CLEAN_EMPTY=1 ;;
      -h | --help)
        fnd::usage
        exit 0
        ;;
      --)
        shift
        [[ $# -gt 0 ]] && FND_TARGET="$1"
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        fnd::usage >&2
        exit 2
        ;;
      *) FND_TARGET="$1" ;;
    esac
    shift
  done
}

fnd::resolve_target() {
  [[ -d $FND_TARGET ]] || log::fatal "Not a directory: $FND_TARGET"
  [[ -w $FND_TARGET ]] || log::fatal "Not writable: $FND_TARGET"
  FND_TARGET=$(realpath -- "$FND_TARGET")
  if [[ $FND_TARGET == "/" ]]; then
    log::fatal "Refusing to flatten the filesystem root"
  fi
}

fnd::collect() {
  local f
  while IFS= read -r -d '' f; do
    FND_FILES+=("$f")
  done < <(find "$FND_TARGET" -xdev -mindepth 2 -type f -print0)

  [[ ${#FND_FILES[@]} -gt 0 ]] || {
    log::info "Nothing nested to flatten under $FND_TARGET"
    exit 0
  }
}

fnd::confirm() {
  [[ $FND_ASSUME_YES == 1 || ${DRY_RUN:-0} == 1 ]] && return 0
  log::warn "About to move ${#FND_FILES[@]} file(s) into $FND_TARGET and empty their folders."
  confirmation::seek "Proceed?"
  confirmation::is_confirmed || log::fatal "Aborted -- nothing moved."
}

# Reserve a collision-free absolute path in FND_TARGET for a basename, returning
# it in FND_DST. Uses a global (not command substitution) so reservations in
# FND_CLAIMED persist across calls -- required for an accurate dry-run, since
# nothing is written to disk to collide against.
fnd::unique_dst() {
  local base="$1" candidate="$FND_TARGET/$1"
  if [[ ! -e $candidate && -z ${FND_CLAIMED[$candidate]:-} ]]; then
    FND_CLAIMED[$candidate]=1
    FND_DST="$candidate"
    return 0
  fi
  local stem ext n=1
  stem=$(file::stem "$base")
  ext=$(file::extension "$base")
  [[ -n $ext ]] && ext=".$ext"
  while :; do
    candidate="$FND_TARGET/${stem}-${n}${ext}"
    if [[ ! -e $candidate && -z ${FND_CLAIMED[$candidate]:-} ]]; then
      FND_CLAIMED[$candidate]=1
      FND_DST="$candidate"
      return 0
    fi
    n=$((n + 1))
  done
}

fnd::flatten() {
  local src base dst ts undo ufd

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    for src in "${FND_FILES[@]}"; do
      fnd::unique_dst "${src##*/}"
      log::info "[dry-run] mv ${src} -> ${FND_DST}"
    done
    return 0
  fi

  ts=$(date +"%Y-%m-%d__%Hh-%Mm-%Ss")
  undo="$FND_TARGET/flatten-undo-${ts}.sh"
  exec {ufd}> "$undo"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "# Undo for the flatten run on ${ts}." \
    '# Recreates the original directories and moves each file back to it.' \
    "# 'mv -n' never overwrites, so an occupied path is skipped, not clobbered." \
    'set -Eeuo pipefail' \
    '' >&"$ufd"

  for src in "${FND_FILES[@]}"; do
    base="${src##*/}"
    fnd::unique_dst "$base"
    dst="$FND_DST"
    mv -- "$src" "$dst"
    printf 'mkdir -p -- %q\nmv -n -- %q %q\n' "${src%/*}" "$dst" "$src" >&"$ufd"
    FND_MOVED=$((FND_MOVED + 1))
  done

  exec {ufd}>&-
  chmod +x "$undo"
  FND_UNDO_FILE="$undo"
}

fnd::clean_empty() {
  [[ $FND_CLEAN_EMPTY == 1 ]] || return 0
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would remove directories left empty under $FND_TARGET"
    return 0
  fi
  find "$FND_TARGET" -xdev -mindepth 1 -type d -empty -delete
  log::info "Removed empty directories."
}

fnd::summary() {
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${#FND_FILES[@]} file(s) would move into $FND_TARGET"
    return 0
  fi
  log::info "Moved ${FND_MOVED} file(s) into $FND_TARGET"
  if [[ -n $FND_UNDO_FILE ]]; then
    log::info "Undo: $FND_UNDO_FILE  (run it to rebuild the original structure)"
  fi
}

main() {
  banner::print "flatten"
  fnd::parse_args "$@"
  fnd::resolve_target
  fnd::collect
  fnd::confirm
  fnd::flatten
  fnd::clean_empty
  fnd::summary
}

main "$@"
