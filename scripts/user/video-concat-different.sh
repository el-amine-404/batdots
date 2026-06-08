#!/usr/bin/env bash
# scripts/user/video-concat-different.sh -- Join videos with differing properties
# by re-encoding. Inputs may have different codecs/resolutions/framerates.
#
# Audio is preserved per-clip: clips that have audio keep it; clips that don't
# get a matched-length silent track synthesized, so the concat never fails and
# no clip's audio is dropped just because a sibling clip was silent.
#
# Usage: video-concat-different.sh <output.mp4> <input1> <input2> [input3...]
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

vcd::usage() {
  log::info "Usage: $(basename "$0") <output.mp4> <input1> <input2> [input3...]"
  exit 1
}

vcd::has_audio() {
  local s
  s=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$1") || return 1
  [[ -n $s ]]
}

vcd::duration() {
  ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 -- "$1"
}

# Largest width and height across all inputs -- the concat canvas. The concat
# filter demands identical video geometry, so every clip is scaled to fit this
# and letterbox-padded; using the max avoids upscaling the biggest source.
vcd::canvas() {
  local f w h maxw=0 maxh=0
  for f in "$@"; do
    IFS=',' read -r w h < <(ffprobe -v error -select_streams v:0 \
      -show_entries stream=width,height -of csv=p=0 -- "$f")
    maxw=$((w > maxw ? w : maxw))
    maxh=$((h > maxh ? h : maxh))
  done
  printf '%s %s\n' "$maxw" "$maxh"
}

vcd::concat() {
  local output="$1"
  shift
  local -a inputs=("$@")

  local f
  for f in "${inputs[@]}"; do
    file::exists "$f" || log::fatal "Input file not found: $f"
    video::is_real_video "$f" || log::fatal "Invalid video file: $f"
  done

  dir::create MERGED

  local n=${#inputs[@]} fps W H
  fps="${DOTFILES_VIDEO_CONCAT_FPS:?DOTFILES_VIDEO_CONCAT_FPS must be set in local/env.sh}"
  read -r W H < <(vcd::canvas "${inputs[@]}")

  # Real inputs occupy ffmpeg indices 0..n-1; synthesized silence inputs are
  # appended after them, taking indices n, n+1, ... in encounter order.
  local -a cmd=(ffmpeg -nostdin -hide_banner -loglevel warning -y)
  for f in "${inputs[@]}"; do
    cmd+=(-i "$f")
  done

  # Normalize every clip to identical geometry/fps/pixel-format and audio to a
  # common rate/layout, so concat succeeds regardless of how the inputs differ.
  local filter="" labels="" i sil=$n dur
  for i in "${!inputs[@]}"; do
    filter+="[${i}:v:0]scale=${W}:${H}:force_original_aspect_ratio=decrease,"
    filter+="pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=${fps},format=yuv420p[v${i}];"
    if vcd::has_audio "${inputs[$i]}"; then
      filter+="[${i}:a:0]"
    else
      dur=$(vcd::duration "${inputs[$i]}")
      cmd+=(-f lavfi -t "$dur" -i "anullsrc=channel_layout=stereo:sample_rate=48000")
      filter+="[${sil}:a:0]"
      sil=$((sil + 1))
    fi
    filter+="aresample=48000,aformat=channel_layouts=stereo[a${i}];"
    labels+="[v${i}][a${i}]"
  done
  filter+="${labels}concat=n=${n}:v=1:a=1[outv][outa]"

  cmd+=(-filter_complex "$filter" -map "[outv]" -map "[outa]"
    -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 160k
    -movflags +faststart -- "MERGED/$output")

  log::info "Concatenating ${n} videos into MERGED/$output (${W}x${H} @ ${fps}fps)..."
  "${cmd[@]}"
  log::info "Merged video saved to MERGED/$output"
}

vcd::main() {
  os::check_dependency ffmpeg ffprobe || exit 1
  [[ $# -ge 3 ]] || vcd::usage
  vcd::concat "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vcd::main "$@"
fi
