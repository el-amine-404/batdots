#!/usr/bin/env bash
source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"
# package-status -- installed vs pinned version for every registry component.
#
# Fully offline: compares the installed copy (lib/status.sh probes) against the
# pinned <COMP>_VERSION in config/versions.conf. No network calls. The media
# capability sections (ffmpeg codecs, imagemagick delegates, hw-accel) probe the
# local toolchain only.
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

# --- THEME --------------------------------------------------------------------
C_GRAY=$'\e[38;5;244m'

ICON_OK="●"
ICON_MISS="○"
ICON_OUTDATED="◐"
ICON_NA="·"

COUNT_OK=0
COUNT_OUTDATED=0
COUNT_MISS=0
COUNT_NA=0

COL_NAME=24
COL_INST=18
COL_PINNED=16

# Capability listings captured once (greping a pipe with `grep -q` + pipefail
# SIGPIPEs the producer and falsely fails the test).
FFMPEG_CODECS=""
MAGICK_FORMATS=""

# --- HELPERS ------------------------------------------------------------------
_pad() { printf "%-${2}s" "${1:0:$((${2} - 1))}"; }

_section() {
  echo ""
  printf '%s%s  %-60s%s\n' "$BOLD" "$FG_WHITE" "$1" "$RESET"
  printf '%s  %s%s\n' "$C_GRAY" "$(printf '%.0s-' {1..68})" "$RESET"
}

# _row <state> <name> <col3> <col4>   state ∈ ok | outdated | missing | na
_row() {
  local state="$1" name="$2" col3="${3:-}" col4="${4:-}"
  local icon color

  case "$state" in
    ok)
      icon="$ICON_OK" color="$FG_GREEN"
      ((COUNT_OK++)) || :
      ;;
    outdated)
      icon="$ICON_OUTDATED" color="$FG_YELLOW"
      ((COUNT_OUTDATED++)) || :
      ;;
    missing)
      icon="$ICON_MISS" color="$FG_RED"
      ((COUNT_MISS++)) || :
      ;;
    *)
      icon="$ICON_NA" color="$C_GRAY"
      ((COUNT_NA++)) || :
      ;;
  esac

  printf '  %s%s%s  ' "$color" "$icon" "$RESET"
  printf '%s%s%s' "$FG_WHITE" "$(_pad "$name" $COL_NAME)" "$RESET"
  printf '%s%s%s' "$color" "$(_pad "$col3" $COL_INST)" "$RESET"
  if [[ -n $col4 ]]; then
    local marker=""
    [[ $state == outdated ]] && marker="↑ "
    printf '%s%s%s%s' "$DIM$C_GRAY" "$marker" "$col4" "$RESET"
  fi
  echo ""
}

# Render an installed-vs-pinned row per component in the named array.
# $1 = section title, $2 = array variable name.
ps::version_section() {
  local title="$1"
  local -n components="$2"
  _section "$title"
  printf '  %s  %s%s%s%s\n' "$DIM$C_GRAY" \
    "$(_pad component $COL_NAME)" "$(_pad installed $COL_INST)" \
    "$(_pad pinned $COL_PINNED)" "$RESET"

  local comp state installed pinned
  for comp in "${components[@]}"; do
    IFS='|' read -r state installed pinned <<< "$(status::compare "$comp")"
    _row "$state" "${comp,,}" "$installed" "$pinned"
  done
}

# --- MEDIA CAPABILITY PROBES (local toolchain only) ---------------------------
check_ffmpeg_codec() {
  local name="$1" codec="$2"
  if [[ -z $FFMPEG_CODECS ]]; then
    _row missing "$name" "(ffmpeg missing)" ""
  elif grep -qP "\b${codec}\b" <<< "$FFMPEG_CODECS"; then
    _row ok "$name" "enabled" ""
  else
    _row missing "$name" "" ""
  fi
}

check_imagemagick_delegate() {
  local name="$1" delegate="$2"
  if [[ -z $MAGICK_FORMATS ]]; then
    _row missing "$name" "(magick missing)" ""
  elif grep -qiP "^\s*${delegate}\b" <<< "$MAGICK_FORMATS"; then
    _row ok "$name" "supported" ""
  else
    _row missing "$name" "" ""
  fi
}

check_vaapi() {
  if ! command::exists vainfo; then
    _row missing "VA-API" "" ""
    return
  fi
  local version
  version=$(vainfo 2> /dev/null | grep -oP 'VA-API version: \K[\d.]+' | head -1 || true)
  if [[ -n $version ]]; then
    _row ok "VA-API" "$version" ""
  else
    _row outdated "VA-API" "present, no output" ""
  fi
}

# --- MAIN ---------------------------------------------------------------------
main() {
  echo ""
  printf '%s%s  package status%s  %s%s%s%s\n' \
    "$BOLD" "$FG_MAGENTA" "$RESET" "$DIM" "$C_GRAY" "$(date '+%Y-%m-%d %H:%M')" "$RESET"
  printf '%s  %s -- installed vs pinned (offline)%s\n' "$C_GRAY" "$(uname -srm)" "$RESET"

  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

  ps::version_section "media stack" MEDIA_STACK_COMPONENTS
  ps::version_section "fonts" FONT_COMPONENTS
  ps::version_section "tools" TOOL_COMPONENTS

  command::exists ffmpeg && FFMPEG_CODECS=$(ffmpeg -hide_banner -codecs 2> /dev/null || true)
  command::exists magick && MAGICK_FORMATS=$(magick -list format 2> /dev/null || true)

  _section "ffmpeg codec support"
  check_ffmpeg_codec "h264 (decode)" h264
  check_ffmpeg_codec "h264 (encode)" libx264
  check_ffmpeg_codec "hevc/h265 (decode)" hevc
  check_ffmpeg_codec "hevc (encode)" libx265
  check_ffmpeg_codec "av1 (decode)" av1
  check_ffmpeg_codec "av1 (encode)" libsvtav1
  check_ffmpeg_codec "vp9" vp9
  check_ffmpeg_codec "aac" aac
  check_ffmpeg_codec "aac (fdk)" libfdk_aac
  check_ffmpeg_codec "mp3 (encode)" libmp3lame
  check_ffmpeg_codec "opus" libopus
  check_ffmpeg_codec "flac" flac
  check_ffmpeg_codec "prores" prores

  _section "imagemagick format support"
  check_imagemagick_delegate "HEIC/HEIF" HEIC
  check_imagemagick_delegate "AVIF" AVIF
  check_imagemagick_delegate "WebP" WEBP
  check_imagemagick_delegate "JPEG XL" JXL
  check_imagemagick_delegate "RAW/DNG" DNG
  check_imagemagick_delegate "PDF" PDF
  check_imagemagick_delegate "SVG" SVG

  _section "hardware acceleration"
  check_vaapi
  if command::exists nvidia-smi; then
    _row ok "NVIDIA (NVDEC/NVENC)" "present" ""
  else
    _row missing "NVIDIA (NVDEC/NVENC)" "" ""
  fi

  # -- summary --
  echo ""
  printf '%s  %s%s\n' "$C_GRAY" "$(printf '%.0s-' {1..68})" "$RESET"
  printf '  %s%s %d ok%s    ' "$FG_GREEN" "$ICON_OK" "$COUNT_OK" "$RESET"
  printf '%s%s %d outdated%s    ' "$FG_YELLOW" "$ICON_OUTDATED" "$COUNT_OUTDATED" "$RESET"
  printf '%s%s %d missing%s    ' "$FG_RED" "$ICON_MISS" "$COUNT_MISS" "$RESET"
  printf '%s%s %d n/a%s\n' "$C_GRAY" "$ICON_NA" "$COUNT_NA" "$RESET"
  echo ""
}

main "$@"
