#!/usr/bin/env bash
# scripts/user/hikvision-to-phone.sh -- Transcode Hikvision MP4s for phones.
#
# Hikvision recordings often use profiles/containers that phones and chat apps
# refuse to play. This re-encodes them to the most broadly compatible H.264
# shape: baseline profile, level 3.1, yuv420p, even dimensions, +faststart.
#
# Audio: real audio is kept when the source has it; clips with no audio track
# get a synthesized silent one, because some players reject video-only MP4s.
#
# Inputs are read non-recursively from IN_DIR (default: cwd); outputs land in
# IN_DIR/OUT_DIR (default: converted/). Encoder knobs are env overrides.
#
# Examples:
#   hikvision-to-phone                       # ./*.mp4  -> ./converted/
#   hikvision-to-phone ~/clips out -f        # ~/clips/*.mp4 -> ~/clips/out/, overwrite
#   CRF=20 MAX_H=1080 hikvision-to-phone     # tune quality/size via env

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

CRF="${CRF:-23}"
PRESET="${PRESET:-veryfast}"
MAX_W="${MAX_W:-1280}"
MAX_H="${MAX_H:-720}"
FPS="${FPS:-30}"
VBV_MAX="${VBV_MAX:-2000}"
VBV_BUF="${VBV_BUF:-4000}"

IN_DIR="."
OUT_DIR="converted"
OUT_PATH=""
FORCE=0
CONVERTED=0
SKIPPED=0
FAILED=0

h2p::usage() {
  cat << EOF
Usage:
  $(basename "$0") [IN_DIR] [OUT_DIR] [options]

Transcode every *.mp4 in IN_DIR (default: .) into phone-compatible H.264,
writing results to IN_DIR/OUT_DIR (default: converted).

Options:
  -f, --force      Overwrite existing outputs (default: skip them)
  -n, --dry-run    Print the ffmpeg commands without running them
  -h, --help       Show this help message

Encoder knobs (environment overrides):
  CRF=$CRF PRESET=$PRESET MAX_W=$MAX_W MAX_H=$MAX_H FPS=$FPS
  VBV_MAX=$VBV_MAX VBV_BUF=$VBV_BUF
EOF
}

h2p::parse_args() {
  local -a pos=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f | --force) FORCE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        h2p::usage
        exit 0
        ;;
      --)
        shift
        pos+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        h2p::usage >&2
        exit 2
        ;;
      *) pos+=("$1") ;;
    esac
    shift
  done

  IN_DIR="${pos[0]:-.}"
  OUT_DIR="${pos[1]:-converted}"
  OUT_PATH="$IN_DIR/$OUT_DIR"

  [[ -d $IN_DIR ]] || log::fatal "Not a directory: $IN_DIR"
}

h2p::require_deps() {
  command::exists ffmpeg \
    || log::fatal "ffmpeg not found -- install the 'ffmpeg' package (run bootstrap to provision it)"
  command::exists ffprobe \
    || log::fatal "ffprobe not found -- it ships with the 'ffmpeg' package"
}

h2p::has_audio() {
  local streams
  streams="$(ffprobe -v error -select_streams a -show_entries stream=index \
    -of csv=p=0 -- "$1")" || return 1
  [[ -n $streams ]]
}

h2p::convert_one() {
  local in_file="$1"
  local base name out_file tmp_file
  base="$(basename -- "$in_file")"
  name="${base%.*}"
  out_file="$OUT_PATH/$name.mp4"

  if [[ -e $out_file && $FORCE != 1 ]]; then
    log::info "Skipping (exists, use --force): $out_file"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  # Keep real audio when present; otherwise synthesize a silent track so
  # players that reject video-only MP4s still accept the file.
  local -a inputs=(-i "$in_file") amap
  if h2p::has_audio "$in_file"; then
    amap=(-map 0:v:0 -map 0:a:0)
  else
    inputs+=(-f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000")
    amap=(-map 0:v:0 -map 1:a:0 -shortest)
  fi

  local -a cmd=(
    ffmpeg -hide_banner -loglevel error -stats -y
    "${inputs[@]}"
    "${amap[@]}"
    -vf "scale='min($MAX_W,iw)':'min($MAX_H,ih)':force_original_aspect_ratio=decrease,setsar=1,pad=ceil(iw/2)*2:ceil(ih/2)*2"
    -r "$FPS"
    -c:v libx264 -profile:v baseline -level 3.1 -pix_fmt yuv420p
    -x264-params "ref=1:bframes=0:weightp=0:vbv-maxrate=$VBV_MAX:vbv-bufsize=$VBV_BUF"
    -crf "$CRF" -preset "$PRESET"
    -c:a aac -b:a 96k
    -movflags +faststart
    -tag:v avc1 -brand mp42
  )

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${cmd[*]} $out_file"
    return 0
  fi

  # Encode to a temp file in the output dir and rename only on success: an
  # interrupted or failed run must never leave a partial file that the
  # "exists" check above would later mistake for a finished conversion.
  tmp_file="$(mktemp -- "$OUT_PATH/.${name}.XXXXXX.mp4")"

  log::info "Converting: $in_file -> $out_file"
  if "${cmd[@]}" "$tmp_file"; then
    mv -f -- "$tmp_file" "$out_file"
    CONVERTED=$((CONVERTED + 1))
  else
    log::error "Failed (leaving original untouched): $in_file"
    rm -f -- "$tmp_file"
    FAILED=$((FAILED + 1))
  fi
}

h2p::convert_all() {
  dir::create "$OUT_PATH"

  shopt -s nullglob nocaseglob
  local in_file found=0
  for in_file in "$IN_DIR"/*.mp4; do
    found=1
    h2p::convert_one "$in_file"
  done
  shopt -u nocaseglob

  [[ $found == 1 ]] || log::warn "No *.mp4 files found in $IN_DIR"
}

main() {
  banner::print "hikvision-to-phone"
  h2p::parse_args "$@"
  h2p::require_deps
  h2p::convert_all

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] done"
  else
    log::info "Done: $CONVERTED converted, $SKIPPED skipped, $FAILED failed -> $OUT_PATH/"
  fi
}

main "$@"
