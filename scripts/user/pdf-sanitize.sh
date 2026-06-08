#!/usr/bin/env bash
# scripts/user/pdf-sanitize.sh -- Make untrusted PDFs safe to open and share.
#
# For files you DON'T trust (downloaded, received from others). Runs ClamAV and
# (if configured) YARA signature scans, then defangs the PDF so active content
# cannot execute:
#
#   structural (default) -- Ghostscript re-distills the file, dropping document
#       JavaScript, /OpenAction, /Launch actions, /EmbeddedFiles and ALL
#       annotations (so Link /URI phishing, Screen/Widget /AA scripts and
#       Movie/RichMedia objects go too), then strips metadata and linearizes.
#       Selectable text and bookmarks survive; hyperlinks and form fields do not.
#   --paranoid           -- every page is rasterized and a fresh PDF is rebuilt
#       from the images. Nothing from the original byte-stream survives, so
#       polyglots and metadata embedded inside page images are neutralized too,
#       at the cost of selectable text and file size.
#
# The sanitized output is then re-checked with pdfcpu (an independent Go parser)
# as a final integrity gate. Each PDF is sanitized IN PLACE; its original is
# archived under ORIGINAL_PDF/ (path-mirrored) for rollback. A file a scanner
# flags as malware is moved to QUARANTINE/ without processing, and a corrupt file
# goes to BAD_PDF/. Re-runs skip files already sanitized.
#
# Usage:
#   pdf-sanitize.sh                    sanitize every PDF in the current dir
#   pdf-sanitize.sh FILE...            sanitize the given files
#   pdf-sanitize.sh DIR                sanitize every PDF in DIR
#
# Options:
#   -p, --paranoid     Rasterize pages instead of re-distilling (max safety)
#       --dpi N        Rasterization DPI for --paranoid (default: 200)
#       --ocr          Add a searchable text layer (ocrmypdf); off by default
#       --report       Show pdfid risk-keyword counts before and after (proves
#                      active content dropped to zero)
#   -r, --recursive    Recurse into subdirectories of any DIR target
#   -n, --dry-run      List what would be sanitized, write nothing
#   -y, --yes          Skip the confirmation prompt (for scripts/non-interactive)
#   -h, --help         Show this help message
#
# This tool REPLACES each PDF in place (original archived under ORIGINAL_PDF/).
# With no target it acts on the current directory, so it shows a summary and asks
# for confirmation first; preview safely with -n, or pass -y to skip the prompt.
#
# Optional detectors degrade gracefully when absent: ClamAV + YARA add signature
# scanning, pdfcpu adds independent validation, pdfid powers --report. Install
# them via the 'docs'/'security' package groups and the yara-rules task.
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

PSAN_RECURSIVE=0
PSAN_ASSUME_YES=0
declare -a PSAN_POS=()

psan::usage() {
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' \
    "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")"
}

psan::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p | --paranoid) export DOTFILES_PDF_SANITIZE_PARANOID=1 ;;
      --dpi)
        shift
        export DOTFILES_PDF_SANITIZE_DPI="${1:?--dpi needs a value}"
        ;;
      --ocr) export DOTFILES_PDF_SANITIZE_OCR=1 ;;
      --report) export DOTFILES_PDF_SANITIZE_REPORT=1 ;;
      -r | --recursive) PSAN_RECURSIVE=1 ;;
      -y | --yes) PSAN_ASSUME_YES=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        psan::usage
        exit 0
        ;;
      --)
        shift
        PSAN_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        psan::usage >&2
        exit 2
        ;;
      *) PSAN_POS+=("$1") ;;
    esac
    shift
  done
}

# Check exactly the tools the selected mode needs, and exit cleanly if any are
# missing. qpdf is required by both modes (validation); structural adds gs +
# exiftool, paranoid adds pdftoppm + an image->PDF builder. An explicitly
# requested --ocr with no ocrmypdf is a hard error (the user asked for it).
psan::require_deps() {
  os::check_dependency qpdf || exit 1
  if [[ ${DOTFILES_PDF_SANITIZE_PARANOID:-} == 1 ]]; then
    os::check_dependency pdftoppm || exit 1
    command::exists img2pdf || command::exists convert \
      || log::fatal "paranoid mode needs img2pdf (preferred) or ImageMagick 'convert' -- install the 'docs' package group"
  else
    os::check_dependency gs exiftool || exit 1
  fi
  if [[ ${DOTFILES_PDF_SANITIZE_OCR:-} == 1 ]]; then
    command::exists ocrmypdf || log::fatal "--ocr requested but ocrmypdf is not installed -- install the 'docs' package group"
  fi
  if [[ ${DOTFILES_PDF_SANITIZE_REPORT:-} == 1 ]]; then
    command::exists pdfid || log::fatal "--report requested but pdfid is not installed -- run the 'pdfid' external task (bootstrap)"
  fi
  command::exists clamscan || log::warn "clamscan not installed -- ClamAV scan skipped (defang still runs)"
  command::exists yara || log::warn "yara not installed -- YARA scan skipped (defang still runs)"
}

psan::list_in_dir() {
  local dir="$1" maxdepth=(-maxdepth 1)
  [[ $PSAN_RECURSIVE == 1 ]] && maxdepth=()
  find "$dir" "${maxdepth[@]}" \
    -type d \( -name ORIGINAL_PDF -o -name BAD_PDF -o -name QUARANTINE \) -prune -o \
    -type f -iname '*.pdf' -print0
}

psan::collect() {
  if [[ ${#PSAN_POS[@]} -eq 0 ]]; then
    psan::list_in_dir .
    return
  fi
  local a
  for a in "${PSAN_POS[@]}"; do
    if [[ -d $a ]]; then
      psan::list_in_dir "$a"
    elif [[ -f $a ]]; then
      printf '%s\0' "$a"
    else
      log::warn "not a file or directory: $a"
    fi
  done
}

# Keep the YARA ruleset current, like ClamAV's freshclam does for its signatures.
# Best-effort and staleness-gated (the task no-ops if fresh), so it refreshes at
# most once a day and NEVER fails the run -- offline just keeps the cached rules.
# Disable with DOTFILES_YARA_AUTO_REFRESH=0.
psan::maybe_refresh_yara() {
  command::exists yara || return 0
  [[ ${DOTFILES_YARA_AUTO_REFRESH:-} == 1 ]] || return 0

  local rules="${DOTFILES_YARA_RULES:?DOTFILES_YARA_RULES must be set in local/env.sh}"
  local max_h="${DOTFILES_YARA_MAX_AGE_HOURS:?DOTFILES_YARA_MAX_AGE_HOURS must be set in local/env.sh}"
  if [[ -s $rules ]]; then
    local age=$(($(date +%s) - $(stat -c %Y "$rules")))
    ((age >= max_h * 3600)) || return 0 # still fresh -- nothing to do
  fi

  log::info "Refreshing YARA ruleset (runs at most once a day; offline-safe)..."
  bash "${DOTFILES_ROOT}/scripts/tasks/external/common/yara-rules.sh" \
    || log::warn "YARA refresh failed -- continuing with existing/no ruleset"
}

# Show exactly what is about to happen and require confirmation, because this
# tool MOVES each original into QUARANTINE/. Skipped with -y; refuses to proceed
# non-interactively without -y (use -n to preview instead).
psan::confirm() {
  local n="$1" mode="structural (re-distill)"
  [[ ${DOTFILES_PDF_SANITIZE_PARANOID:-} == 1 ]] && mode="paranoid (rasterize)"
  log::warn "About to sanitize ${n} PDF(s) IN PLACE -- mode: ${mode}"
  log::warn "  • each PDF is replaced by its cleaned version"
  log::warn "  • each ORIGINAL is archived under ORIGINAL_PDF/ (rollback)"
  log::warn "  • malware-flagged -> QUARANTINE/, corrupt -> BAD_PDF/"
  log::warn "  (preview with -n/--dry-run; skip this prompt with -y/--yes)"
  [[ $PSAN_ASSUME_YES == 1 ]] && return 0
  if [[ ! -t 0 ]]; then
    log::error "Refusing to modify files non-interactively without -y/--yes"
    return 1
  fi
  confirmation::seek "Continue?"
  confirmation::is_confirmed
}

psan::run() {
  local f
  local -a targets=()
  while IFS= read -r -d '' f; do targets+=("$f"); done < <(psan::collect)

  local n=${#targets[@]}
  [[ $n -gt 0 ]] || {
    log::warn "No PDFs found to sanitize (run with -h for help, -n to preview)"
    return 0
  }

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${n} PDF(s) would be sanitized in place (originals -> ORIGINAL_PDF/):"
    for f in "${targets[@]}"; do log::info "  $f"; done
    return 0
  fi

  psan::confirm "$n" || {
    log::info "Aborted -- nothing was changed."
    return 0
  }

  psan::maybe_refresh_yara

  local ok=0 failed=0
  for f in "${targets[@]}"; do
    if pdf::sanitize "$f"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
    fi
  done
  log::info "Done: ${ok} sanitized in place, ${failed} flagged/failed (originals -> ORIGINAL_PDF/; threats -> QUARANTINE/, corrupt -> BAD_PDF/)"
}

main() {
  banner::print "pdf sanitize"
  psan::parse_args "$@"
  psan::require_deps
  psan::run
}

main "$@"
