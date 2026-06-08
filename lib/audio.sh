#!/usr/bin/env bash
# True if FILE is a non-corrupt audio (or audio-bearing) stream.
# Warning: decodes the entire file to check for corruption. Slow.
audio::is_real_audio() {
  local file="${1:?audio::is_real_audio requires a file}"
  local mime
  mime=$(file -b --mime-type "$file" 2> /dev/null)

  case "$mime" in
    audio/* | video/* | application/ogg) ;;
    *)
      log::error "$file: not audio (mime=$mime)"
      return 1
      ;;
  esac

  if ! ffmpeg -nostdin -v error -xerror -i "$file" -vn -f null - 2> /dev/null; then
    log::error "$file: corrupt or unreadable audio"
    return 1
  fi
}

# Optimize an MP3 in place. The original is moved to ./ORIGINAL_AUDIO/.
audio::optimize_mp3() {
  local input="${1:?audio::optimize_mp3 requires an audio file}"
  os::check_dependency ffmpeg file || return 1
  file::is_readable "$input" || return 1
  audio::is_real_audio "$input" || return 1

  local archive="ORIGINAL_AUDIO/$(basename -- "$input")"
  dir::create ORIGINAL_AUDIO
  file::move "$input" "$archive" || return 1

  ffmpeg -nostdin -i "$archive" -vn -map_metadata -1 \
    -c:a libmp3lame -b:a 128k "$input" \
    && log::info "optimized: $input" \
    || {
      log::error "optimize failed: $input"
      return 1
    }
}

# Strip an MP3 to a clean, audio-only stream in place: drop every tag, the
# embedded album art, chapters, and any non-audio stream -- the usual hiding
# places for payloads and the parsers attackers target. The original is moved
# to ./ORIGINAL_AUDIO/ first, and restored if the rewrite fails. With
# --reencode it fully re-decodes/re-encodes (lossy, ~V0), which additionally
# purges appended or embedded data and crafted frames that a stream copy keeps.
audio::sanitize_mp3() {
  local input="${1:?audio::sanitize_mp3 requires an audio file}"
  local reencode=0
  [[ ${2:-} == "--reencode" ]] && reencode=1
  os::check_dependency ffmpeg file || return 1
  file::is_readable "$input" || return 1

  local archive="ORIGINAL_AUDIO/$(basename -- "$input")"
  dir::create ORIGINAL_AUDIO
  file::move "$input" "$archive" || return 1

  local -a enc=(-c:a copy)
  [[ $reencode == 1 ]] && enc=(-c:a libmp3lame -q:a 0)

  if ffmpeg -nostdin -v error -i "$archive" \
    -map 0:a:0 -map_metadata -1 -map_chapters -1 \
    "${enc[@]}" -fflags +bitexact "$input"; then
    log::info "sanitized: $input"
  else
    file::move "$archive" "$input"
    log::error "sanitize failed (original restored): $input"
    return 1
  fi
}

# Extract metadata from an audio file.
# Returns a string: "Artist - Title (Album)"
audio::get_metadata() {
  local file="${1:?audio::get_metadata requires a file}"
  os::check_dependency ffprobe || return 1

  local title artist album
  title=$(ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file" | xargs)
  artist=$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file" | xargs)
  album=$(ffprobe -v quiet -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$file" | xargs)

  if [[ -n $title ]]; then
    local result=""
    [[ -n $artist ]] && result="${artist} - "
    result+="${title}"
    [[ -n $album ]] && result+=" (${album})"
    printf '%s\n' "$result"
  else
    basename -- "$file"
  fi
}

# Play one or more audio files using the best available player.
# Priorities: mpv > ffplay > aplay
audio::play() {
  (($# > 0)) || {
    log::error "audio::play requires at least one file"
    return 1
  }

  local files=("$@")
  local first="${files[0]}"

  # If only one file, show metadata
  if [[ ${#files[@]} -eq 1 ]]; then
    local info
    info=$(audio::get_metadata "$first" 2> /dev/null || basename -- "$first")
    log::info "Now Playing: $info"
  else
    log::info "Starting playlist (${#files[@]} tracks)..."
  fi

  if command -v mpv > /dev/null 2>&1; then
    # mpv handles multiple files as a playlist natively.
    # --force-window ensures the GUI is launched even for audio.
    mpv --force-window --osd-level=2 --quiet --playlist-start=0 -- "${files[@]}"
  elif command -v ffplay > /dev/null 2>&1; then
    # ffplay doesn't have a native playlist, we loop through them
    local f
    for f in "${files[@]}"; do
      log::info "Now Playing: $(audio::get_metadata "$f" 2> /dev/null || basename -- "$f")"
      ffplay -nodisp -autoexit -loglevel quiet -- "$f"
    done
  elif command -v aplay > /dev/null 2>&1; then
    local f
    for f in "${files[@]}"; do
      log::info "Now Playing: $(basename -- "$f")"
      aplay -q -- "$f"
    done
  else
    log::error "No audio player found (mpv, ffplay, or aplay required)"
    return 1
  fi
}
