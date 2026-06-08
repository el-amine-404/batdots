#!/usr/bin/env bash
# Video validators and converters

video::is_real_video() {
  local f="${1:?video::is_real_video requires a path}"
  [[ -f $f && -s $f ]] || {
    log::error "missing or empty: $f"
    return 1
  }

  local mime
  mime=$(file --mime-type -b -- "$f" 2> /dev/null || true)
  case "$mime" in
    video/* | application/x-matroska | application/matroska | application/mp4 | application/ogg) ;;
    *) log::warn "non-obvious MIME ($mime), continuing -- ffprobe will decide" ;;
  esac

  ffprobe -v error -show_format -show_streams -of csv=p=0 -- "$f" > /dev/null 2>&1 \
    || {
      log::error "ffprobe parse failed: $f"
      return 1
    }

  local vcodec
  vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 -- "$f" 2> /dev/null)
  [[ -n $vcodec && $vcodec != "unknown" ]] || {
    log::error "no usable video stream: $f"
    return 1
  }

  ffmpeg -v error -xerror -nostdin -hide_banner -loglevel error \
    -i "$f" -map 0:v:0 -frames:v 1 -f null - > /dev/null 2>&1 \
    || {
      log::error "first-frame decode failed: $f"
      return 1
    }

  local dur
  dur=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 -- "$f" 2> /dev/null)
  awk -v d="$dur" 'BEGIN { exit !(d+0 > 0.1) }' \
    || {
      log::error "invalid/zero duration ($dur): $f"
      return 1
    }
}

# Returns best-guess capture time in ISO-8601.
# Strategy: ExifTool -> ffprobe tags -> Filesystem mtime (stat).
video::shot_datetime() {
  local f="${1:-}"
  [[ -f $f ]] || {
    printf ''
    return 1
  }

  local out
  # 1. ExifTool (Gold Standard)
  if command -v exiftool &> /dev/null; then
    out=$(exiftool -api QuickTimeUTC=1 -s3 -d '%Y-%m-%dT%H:%M:%S%z' \
      -ContentCreateDate -CreateDate -MediaCreateDate -TrackCreateDate -DateTimeOriginal \
      -- "$f" 2> /dev/null | head -n1)
    [[ -n $out ]] && {
      printf '%s' "$out"
      return 0
    }
  fi

  # 2. ffprobe (Metadata tags)
  if command -v ffprobe &> /dev/null; then
    local tag
    for tag in 'format_tags=creation_time' 'stream_tags=creation_time' \
      'format_tags=date' 'format_tags=com.apple.quicktime.creationdate'; do
      out=$(ffprobe -v error -show_entries "$tag" -of default=nw=1:nk=1 -- "$f" 2> /dev/null)
      [[ -n $out ]] && {
        printf '%s' "$out"
        return 0
      }
    done
  fi

  # 3. stat (Filesystem fallback)
  if [[ $(uname) == "Linux" ]]; then
    out=$(stat -c '%y' -- "$f" 2> /dev/null | cut -d'.' -f1 | sed 's/ /T/')
    [[ -n $out ]] && {
      printf '%sZ' "$out"
      return 0
    }
  fi

  return 1
}

# Alias for backward compatibility with old scripts
video::get_date() {
  video::shot_datetime "$@"
}

# Validates a video. If corrupt, moves it to a 'BAD_VIDEO' folder.
# Returns 0 if valid, 1 if corrupt/moved.
video::validate() {
  local f="${1:?video::validate requires a file}"

  if video::is_real_video "$f"; then
    return 0
  else
    log::warn "Video corrupt or invalid: $f"
    dir::create "BAD_VIDEO"
    file::move "$f" "BAD_VIDEO/$(basename -- "$f")"
    return 1
  fi
}

video::wipe_metadata() {
  local f="${1:?video::wipe_metadata requires a file}"
  [[ -f $f ]] || {
    log::error "missing: $f"
    return 1
  }

  if exiftool -overwrite_original_in_place -m -all= \
    -XMP:all= -IPTC:all= -EXIF:all= -MakerNotes:all= \
    -QuickTime:all= -Keys:all= -ItemList:all= -UserData:all= \
    -date= -DateTimeOriginal= -CreateDate= -ModifyDate= \
    -TrackCreateDate= -TrackModifyDate= \
    -MediaCreateDate= -MediaModifyDate= \
    -- "$f"; then
    log::info "metadata wiped: $f"
  else
    log::error "metadata wipe failed: $f"
    return 1
  fi
}

video::copy_date_metadata() {
  local src="${1:?source}" dst="${2:?destination}"
  [[ -f $src ]] || {
    log::error "missing src: $src"
    return 1
  }
  [[ -f $dst ]] || {
    log::error "missing dst: $dst"
    return 1
  }

  if exiftool -overwrite_original_in_place -api QuickTimeUTC=1 \
    -tagsFromFile "$src" \
    -date -DateTimeOriginal -CreateDate -ModifyDate \
    -TrackCreateDate -TrackModifyDate \
    -MediaCreateDate -MediaModifyDate \
    '-FileModifyDate<CreateDate' \
    -- "$dst"; then
    log::info "date metadata copied: $src -> $dst"
  else
    log::error "exiftool date copy failed"
    return 1
  fi
}

# Emits NUL-delimited paths of video files directly under $1 (default: cwd),
# sorted. The single source of truth for "which extensions are videos".
video::list_in_dir() {
  local dir="${1:-.}"
  find "$dir" -maxdepth 1 -type f \
    \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.avi' \
    -o -iname '*.mts' -o -iname '*.m2ts' -o -iname '*.mpg' -o -iname '*.mpeg' \
    -o -iname '*.3gp' -o -iname '*.webm' -o -iname '*.flv' -o -iname '*.wmv' \
    -o -iname '*.m4v' -o -iname '*.ts' \) \
    -print0 | sort -z
}

# Storage-optimizing archive: HEVC video, every audio + subtitle track copied
# untouched (Atmos / multichannel / multiple tracks survive), source resolution,
# bit depth and metadata preserved. Original is moved aside, never deleted.
video::storage_archive() {
  local input="${1:?video::storage_archive requires a file}"
  os::check_dependency ffmpeg ffprobe || return 1
  file::is_readable "$input" || return 1
  video::is_real_video "$input" || return 1

  local base output archive crf preset
  crf="${DOTFILES_VIDEO_ARCHIVE_CRF:?DOTFILES_VIDEO_ARCHIVE_CRF must be set in local/env.sh}"
  preset="${DOTFILES_VIDEO_ARCHIVE_PRESET:?DOTFILES_VIDEO_ARCHIVE_PRESET must be set in local/env.sh}"
  base=$(basename -- "$input")
  archive="ORIGINAL_VIDEOS/${base}"
  output=$(string::next_available_path "${base%.*}.mkv")

  dir::create ORIGINAL_VIDEOS
  file::move "$input" "$archive" || return 1

  log::info "archiving (HEVC crf=$crf, all audio+subs copied): $archive -> $output"
  if ffmpeg -nostdin -y -hide_banner -loglevel warning \
    -i "$archive" \
    -map 0:v:0 -map 0:a? -map 0:s? \
    -map_chapters 0 -map_metadata 0 \
    -c:v libx265 -crf "$crf" -preset "$preset" -x265-params log-level=error \
    -c:a copy -c:s copy \
    -f matroska -- "$output"; then
    log::info "archived: $output"
  else
    log::error "archive failed (original safe in $archive): $input"
    rm -f -- "$output"
    return 1
  fi
}

video::compress_share() {
  local input="${1:?video::compress_share requires a file}"
  os::check_dependency ffmpeg ffprobe exiftool || return 1
  file::is_readable "$input" || return 1
  video::is_real_video "$input" || return 1

  local base output archive
  base=$(basename -- "$input")
  archive="ORIGINAL_VIDEOS/${base}"
  output=$(string::next_available_path "${base%%.*}.mp4")

  dir::create ORIGINAL_VIDEOS
  file::move "$input" "$archive" || return 1

  log::info "compressing (H.264/AAC): $archive -> $output"
  ffmpeg -nostdin -y -hide_banner -loglevel warning \
    -i "$archive" \
    -map 0:v:0 -map 0:a:0? -map -0:s -map -0:t -map -0:d -dn \
    -map_chapters -1 -map_metadata -1 \
    -c:v libx264 -preset medium -crf 28 -pix_fmt yuv420p \
    -profile:v high -level 4.1 \
    -x264-params "keyint=240:min-keyint=24:no-scenecut=1" \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    -- "$output" \
    || {
      log::error "compress failed: $input"
      return 1
    }

  video::wipe_metadata "$output"
  video::copy_date_metadata "$archive" "$output"
  log::info "compressed: $output"
}

# ClamAV signature scan. Returns 1 only when a known infection is found (and
# quarantines the file); a missing scanner or scan error is non-fatal so the
# re-encode sanitization below still runs.
video::_clamav_scan() {
  local f="${1:?video::_clamav_scan requires a file}"
  command::exists clamscan || {
    log::warn "clamscan not installed -- skipping signature scan (install the 'clamav' package)"
    return 0
  }

  local rc=0
  clamscan --no-summary --infected -- "$f" || rc=$?
  case "$rc" in
    0) return 0 ;;
    1)
      log::error "MALWARE DETECTED by ClamAV: $f"
      dir::create QUARANTINE
      file::move "$f" "QUARANTINE/$(basename -- "$f")"
      return 1
      ;;
    *) log::warn "clamscan error (rc=$rc) -- continuing with re-encode sanitization" ;;
  esac
}

# Maximum sanitization for untrusted files: signature scan, then a full
# re-encode of BOTH video and audio with every non-A/V stream and all metadata
# dropped. Nothing from the original container survives as a bitstream, which
# neutralizes polyglots, embedded attachments and metadata-borne payloads.
# Atmos / lossless audio is lost here by design -- run this only on files you
# do not trust, never on your own footage (use video::storage_archive for that).
video::sanitize() {
  local input="${1:?video::sanitize requires a file}"
  os::check_dependency ffmpeg ffprobe || return 1
  file::is_readable "$input" || return 1

  video::_clamav_scan "$input" || return 1

  video::is_real_video "$input" || {
    log::error "not a decodable video, refusing to sanitize: $input"
    return 1
  }

  local base output crf preset
  crf="${DOTFILES_VIDEO_SANITIZE_CRF:?DOTFILES_VIDEO_SANITIZE_CRF must be set in local/env.sh}"
  preset="${DOTFILES_VIDEO_SANITIZE_PRESET:?DOTFILES_VIDEO_SANITIZE_PRESET must be set in local/env.sh}"
  base=$(basename -- "$input")
  output=$(string::next_available_path "CLEAN/${base%.*}.mp4")

  dir::create CLEAN
  log::info "sanitizing (full re-encode, metadata + extra streams dropped): $input -> $output"
  if ffmpeg -nostdin -y -hide_banner -loglevel warning \
    -i "$input" \
    -map 0:v:0 -map 0:a:0? \
    -map_metadata -1 -map_chapters -1 -dn -sn \
    -c:v libx265 -crf "$crf" -preset "$preset" -pix_fmt yuv420p -tag:v hvc1 \
    -c:a aac -b:a 160k \
    -movflags +faststart \
    -f mp4 -- "$output" \
    && video::is_real_video "$output"; then
    dir::create QUARANTINE
    file::move "$input" "QUARANTINE/$base"
    log::info "sanitized: $output (original quarantined in QUARANTINE/)"
  else
    log::error "sanitize failed: $input"
    rm -f -- "$output"
    return 1
  fi
}

# Attempts to recover a file that fails validation. First a stream-copy remux
# (rebuilds a broken index / truncated moov without re-encoding), then a
# corrupt-tolerant full re-encode of whatever still decodes. Repaired output
# lands in REPAIRED/; the original is left untouched.
video::repair() {
  local input="${1:?video::repair requires a file}"
  os::check_dependency ffmpeg ffprobe || return 1
  [[ -f $input ]] || {
    log::error "missing: $input"
    return 1
  }

  local base out
  base=$(basename -- "$input")
  dir::create REPAIRED

  out=$(string::next_available_path "REPAIRED/${base%.*}.mkv")
  log::info "repair attempt 1/2 (remux): $input"
  if ffmpeg -nostdin -y -hide_banner -loglevel error -err_detect ignore_err \
    -i "$input" -map 0 -c copy -f matroska -- "$out" > /dev/null 2>&1 \
    && video::is_real_video "$out" > /dev/null 2>&1; then
    log::info "repaired via remux: $out"
    return 0
  fi
  rm -f -- "$out"

  out=$(string::next_available_path "REPAIRED/${base%.*}.mkv")
  log::info "repair attempt 2/2 (re-encode): $input"
  if ffmpeg -nostdin -y -hide_banner -loglevel error \
    -err_detect ignore_err -fflags +discardcorrupt \
    -i "$input" -map 0:v:0 -map 0:a? \
    -c:v libx265 -crf 23 -preset medium -c:a aac -b:a 160k \
    -f matroska -- "$out" > /dev/null 2>&1 \
    && video::is_real_video "$out" > /dev/null 2>&1; then
    log::info "repaired via re-encode: $out"
    return 0
  fi
  rm -f -- "$out"

  log::error "repair failed -- file is not recoverable: $input"
  return 1
}
