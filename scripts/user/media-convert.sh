#!/usr/bin/env bash
# scripts/user/media-convert.sh -- Convert media between formats with ffmpeg.
#
# One engine instead of a script per format pair: the target extension selects
# a recipe, and ffmpeg infers everything else from the file extensions. Adding
# mkv/webm/avi/mov -> mp4 is free (they all match the mp4 recipe); a genuinely
# new recipe is one case branch below, never a new file.
#
# Recipes (keyed on the TARGET extension):
#   mp4  -> H.264 + yuv420p + even dimensions + faststart (broad/web compatible)
#   gif  -> two-pass palette (palettegen/paletteuse) for clean colours
#   *    -> bare 'ffmpeg -i in out' (ffmpeg picks the muxer from the extension)
#
# Examples:
#   media-convert --to mp4 clip.mkv a.gif        # explicit files
#   media-convert --from gif --to mp4            # every *.gif in the cwd
#   media-convert --from mov --to mp4 ~/vids -r  # recursive under a directory
#   media-convert --to gif clip.mp4 --ss 5 --duration 3

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

MC_TO=""
MC_FROM=""
MC_RECURSIVE=0
MC_FORCE=0
MC_SS=""
MC_DURATION=""
MC_CONVERTED=0
MC_SKIPPED=0
declare -a MC_POS=()
declare -a MC_INPUTS=()
declare -a MC_ARGS=()

mc::usage() {
  cat << EOF
Usage:
  $(basename "$0") --to EXT FILE...                 convert the given files
  $(basename "$0") --from EXT --to EXT [DIR] [-r]    convert every *.EXT under DIR

Options:
  --to EXT           Target format/extension (required), e.g. mp4, gif, webm
  --from EXT         Search mode: convert every *.EXT (case-insensitive)
  -r, --recursive    Recurse into subdirectories (search mode only)
  -f, --force        Overwrite existing outputs (default: skip them)
      --ss TIME      Start offset (HH:MM:SS or seconds) -- trims the input
  -d, --duration N   Output duration in seconds -- trims the input
  -n, --dry-run      Print the ffmpeg commands without running them
  -h, --help         Show this help message
EOF
}

mc::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --to)
        shift
        MC_TO="${1:?--to needs an extension}"
        ;;
      --from)
        shift
        MC_FROM="${1:?--from needs an extension}"
        ;;
      -r | --recursive) MC_RECURSIVE=1 ;;
      -f | --force) MC_FORCE=1 ;;
      --ss)
        shift
        MC_SS="${1:?--ss needs a value}"
        ;;
      -d | --duration)
        shift
        MC_DURATION="${1:?--duration needs a value}"
        ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        mc::usage
        exit 0
        ;;
      --)
        shift
        MC_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        mc::usage >&2
        exit 2
        ;;
      *) MC_POS+=("$1") ;;
    esac
    shift
  done

  MC_TO="${MC_TO,,}"
  MC_FROM="${MC_FROM,,}"
  [[ -n $MC_TO ]] || {
    log::error "--to is required"
    mc::usage >&2
    exit 2
  }
}

mc::require_deps() {
  command::exists ffmpeg \
    || log::fatal "ffmpeg not found -- install the 'ffmpeg' package (run bootstrap to provision it)"
}

# Per-target recipe: fills MC_ARGS with the ffmpeg options between -i and output.
mc::recipe() {
  case "$MC_TO" in
    mp4)
      MC_ARGS=(-c:v libx264 -pix_fmt yuv420p -movflags +faststart
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2")
      ;;
    gif)
      MC_ARGS=(-filter_complex
        "fps=10,scale=360:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse")
      ;;
    *) MC_ARGS=() ;;
  esac
}

mc::collect_inputs() {
  if [[ -n $MC_FROM ]]; then
    local dir="${MC_POS[0]:-.}"
    [[ -d $dir ]] || log::fatal "Not a directory: $dir"
    local maxdepth=(-maxdepth 1)
    [[ $MC_RECURSIVE == 1 ]] && maxdepth=()
    local f
    while IFS= read -r -d '' f; do
      MC_INPUTS+=("$f")
    done < <(find "$dir" "${maxdepth[@]}" -type f -iname "*.${MC_FROM}" -print0)
  else
    [[ ${#MC_POS[@]} -gt 0 ]] || {
      log::error "No input files given (pass files, or use --from EXT)"
      mc::usage >&2
      exit 2
    }
    MC_INPUTS=("${MC_POS[@]}")
  fi

  [[ ${#MC_INPUTS[@]} -gt 0 ]] || {
    log::info "No matching input files."
    exit 0
  }
}

mc::convert_one() {
  local input="$1"
  file::exists "$input" || return 0

  local in_ext="${input##*.}"
  if [[ ${in_ext,,} == "$MC_TO" ]]; then
    log::info "skip (already .$MC_TO): $input"
    MC_SKIPPED=$((MC_SKIPPED + 1))
    return 0
  fi

  local output="${input%.*}.${MC_TO}"
  if [[ -e $output && $MC_FORCE != 1 ]]; then
    log::info "skip (exists, use --force): $output"
    MC_SKIPPED=$((MC_SKIPPED + 1))
    return 0
  fi

  local cmd=(ffmpeg -hide_banner -loglevel warning -y)
  [[ -n $MC_SS ]] && cmd+=(-ss "$MC_SS")
  cmd+=(-i "$input")
  [[ -n $MC_DURATION ]] && cmd+=(-t "$MC_DURATION")
  cmd+=("${MC_ARGS[@]}" "$output")

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${cmd[*]}"
    return 0
  fi

  log::info "Converting $input -> $output"
  "${cmd[@]}"
  MC_CONVERTED=$((MC_CONVERTED + 1))
}

main() {
  banner::print "media-convert"
  mc::parse_args "$@"
  mc::require_deps
  mc::recipe
  mc::collect_inputs

  local input
  for input in "${MC_INPUTS[@]}"; do
    mc::convert_one "$input"
  done

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${#MC_INPUTS[@]} input(s) considered"
  else
    log::info "Done: ${MC_CONVERTED} converted, ${MC_SKIPPED} skipped"
  fi
}

main "$@"
