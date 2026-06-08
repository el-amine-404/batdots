#!/usr/bin/env bash
# scripts/user/mp3-safe.sh -- Harden a music library against malicious MP3s.
#
# An MP3 can't run by itself; the real risks are (a) it isn't actually audio
# (an executable/script/archive renamed .mp3, or a polyglot), (b) it carries a
# payload or a parser exploit in its tags / album art, or (c) it's a crafted
# stream that targets a decoder bug. Each file runs three defensive layers:
#
#   1. real-audio gate -- mime must be audio AND the file must fully decode
#                        (ffmpeg -xerror). Fakes, polyglots and corrupt/crafted
#                        streams are quarantined, never played.
#   2. virus scan      -- clamscan, if installed (best effort); signature hits
#                        are quarantined.
#   3. sanitize        -- strip all tags, album art, chapters and non-audio
#                        streams (the usual payload/exploit surface). With
#                        --reencode the audio is also re-encoded (lossy), which
#                        purges appended/embedded data and crafted frames too.
#
# Originals are archived to ./ORIGINAL_AUDIO/ before sanitizing; suspicious
# files go to ./QUARANTINE/. Nothing is ever deleted.
#
# Examples:
#   mp3-safe                       # every .mp3 in ./ (top level), sanitize
#   mp3-safe ~/Music -r            # whole library, recursively
#   mp3-safe song.mp3 other.mp3    # specific files
#   mp3-safe ~/Music -r --reencode # paranoid: re-encode every track
#   mp3-safe ~/Music -r -n         # dry-run: report, change nothing

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

M3S_RECURSIVE=0
M3S_REENCODE=0
M3S_QUARANTINE_DIR="QUARANTINE"
declare -a M3S_POS=()
declare -a M3S_INPUTS=()
declare -A M3S_INFECTED=()
M3S_SANITIZED=0
M3S_QUARANTINED=0
M3S_FAILED=0

m3s::usage() {
  cat << EOF
Usage:
  $(basename "$0") [FILE...] [options]   harden the given .mp3 files
  $(basename "$0") [DIR] [options]       harden every .mp3 in DIR (default: .)

Options:
  -r, --recursive   Recurse into subdirectories (directory mode only)
      --reencode    Re-encode audio (lossy, ~V0); also purges appended/embedded
                    payloads and crafted frames. Default keeps audio bit-exact.
  -n, --dry-run     Report what would happen; change nothing.
  -h, --help        Show this help message

Per file: verify it is real audio, virus-scan it (clamscan if installed), then
strip all metadata/album-art/non-audio streams. Suspicious files are moved to
./QUARANTINE/; originals are archived to ./ORIGINAL_AUDIO/. Nothing is deleted.
EOF
}

m3s::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --recursive) M3S_RECURSIVE=1 ;;
      --reencode) M3S_REENCODE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        m3s::usage
        exit 0
        ;;
      --)
        shift
        M3S_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        m3s::usage >&2
        exit 2
        ;;
      *) M3S_POS+=("$1") ;;
    esac
    shift
  done
}

m3s::require_deps() {
  os::check_dependency ffmpeg file || log::fatal "ffmpeg and file are required"
  command::exists clamscan \
    || log::warn "clamav not installed -- skipping the virus-scan layer (install 'clamav' to enable it)"
}

m3s::all_regular_files() {
  local p
  for p in "$@"; do
    [[ -f $p ]] || return 1
  done
}

m3s::collect_inputs() {
  # Explicit-file mode: every positional is a file -- process exactly those.
  if [[ ${#M3S_POS[@]} -gt 0 ]] && m3s::all_regular_files "${M3S_POS[@]}"; then
    M3S_INPUTS=("${M3S_POS[@]}")
    return 0
  fi

  # Directory mode: at most one positional, which must be a directory.
  [[ ${#M3S_POS[@]} -le 1 ]] || {
    log::error "Pass .mp3 files, or a single directory to scan -- not both"
    m3s::usage >&2
    exit 2
  }
  local dir="${M3S_POS[0]:-.}"
  [[ -d $dir ]] || log::fatal "Not a directory: $dir"

  local maxdepth=(-maxdepth 1)
  [[ $M3S_RECURSIVE == 1 ]] && maxdepth=()

  # Prune our own archive/quarantine dirs so re-runs don't reprocess them.
  local f
  while IFS= read -r -d '' f; do
    M3S_INPUTS+=("$f")
  done < <(find "$dir" "${maxdepth[@]}" \
    -type d \( -name ORIGINAL_AUDIO -o -name "$M3S_QUARANTINE_DIR" \) -prune -o \
    -type f -iname '*.mp3' -print0)

  [[ ${#M3S_INPUTS[@]} -gt 0 ]] || {
    log::info "No .mp3 files found in $dir"
    exit 0
  }
}

# One clamscan invocation for the whole batch (the DB load dominates per-call
# cost). Records every flagged path in M3S_INFECTED.
m3s::scan_for_viruses() {
  command::exists clamscan || return 0
  log::info "Virus-scanning ${#M3S_INPUTS[@]} file(s)..."
  local line f
  while IFS= read -r line; do
    f="${line%: *FOUND}"
    [[ $f != "$line" ]] && M3S_INFECTED["$f"]=1
  done < <(clamscan --no-summary --infected -- "${M3S_INPUTS[@]}" 2> /dev/null)
}

m3s::quarantine() {
  local f="$1" reason="$2"
  log::warn "QUARANTINE ($reason): $f"
  M3S_QUARANTINED=$((M3S_QUARANTINED + 1))
  [[ ${DRY_RUN:-0} == 1 ]] && return 0
  dir::create "$M3S_QUARANTINE_DIR"
  file::move "$f" "$M3S_QUARANTINE_DIR/" || log::error "failed to quarantine: $f"
}

m3s::process_one() {
  local f="$1" reason=""
  if ! audio::is_real_audio "$f"; then
    reason="not real audio"
  elif [[ -n ${M3S_INFECTED[$f]:-} ]]; then
    reason="virus signature"
  fi

  if [[ -n $reason ]]; then
    m3s::quarantine "$f" "$reason"
    return 0
  fi

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would sanitize: $f"
    M3S_SANITIZED=$((M3S_SANITIZED + 1))
    return 0
  fi

  local -a opt=()
  [[ $M3S_REENCODE == 1 ]] && opt=(--reencode)
  if audio::sanitize_mp3 "$f" "${opt[@]}"; then
    M3S_SANITIZED=$((M3S_SANITIZED + 1))
  else
    M3S_FAILED=$((M3S_FAILED + 1))
  fi
}

main() {
  banner::print "mp3 safe"
  m3s::parse_args "$@"
  m3s::require_deps
  m3s::collect_inputs
  m3s::scan_for_viruses

  local f
  for f in "${M3S_INPUTS[@]}"; do
    m3s::process_one "$f"
  done

  local verb="Done"
  [[ ${DRY_RUN:-0} == 1 ]] && verb="[dry-run]"
  log::info "$verb: $M3S_SANITIZED sanitized, $M3S_QUARANTINED quarantined, $M3S_FAILED failed"
}

main "$@"
