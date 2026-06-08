#!/usr/bin/env bash
# Image validators and optimizers. Before optimizing in place, the original is
# archived (not deleted) so the operator can roll back. The archive mirrors the
# source path under ORIGINAL_PNG/ORIGINAL_JPEG, so files that share a basename
# across directories never collide; an already-archived file is left untouched
# and skipped, making repeated runs idempotent instead of re-quantizing.

# Archive INPUT under ROOT, mirroring its path (relative to cwd when inside it,
# otherwise its absolute path minus the leading slash) so same-named files in
# different directories don't overwrite each other's backup. Returns 2 when the
# original is already archived -- the signal that this file was optimized on an
# earlier run and should be skipped.
image::_archive_original() {
  local root="${1:?image::_archive_original requires ROOT}"
  local input="${2:?image::_archive_original requires INPUT}"
  local abs cwd rel dest
  abs="$(readlink -f -- "$input")"
  cwd="$(pwd -P)"
  if [[ $abs == "$cwd"/* ]]; then
    rel="${abs#"$cwd"/}"
  else
    rel="${abs#/}"
  fi
  dest="$root/$rel"

  [[ -e $dest ]] && return 2
  dir::create "$(dirname -- "$dest")" || return 1
  file::copy "$input" "$dest"
}

image::is_real_jpeg() {
  local path="${1:?image::is_real_jpeg requires a path}"
  file --mime-type -b "$path" 2> /dev/null | grep -qx 'image/jpeg' || return 1
  jpegtran -copy none -outfile /dev/null "$path" > /dev/null 2>&1 || return 1
  jpeginfo -c "$path" > /dev/null 2>&1 || return 1
}

image::optimize_jpg() {
  local input="${1:?image::optimize_jpg requires a file}"
  os::check_dependency jpegoptim jpeginfo jpegtran file || return 1
  file::is_readable "$input" || return 1
  image::is_real_jpeg "$input" || {
    log::error "$input: not a valid JPEG"
    return 1
  }

  local rc=0
  image::_archive_original ORIGINAL_JPEG "$input" || rc=$?
  case $rc in
    0) ;;
    2)
      log::info "already optimized (original archived): $input"
      return 0
      ;;
    *) return 1 ;;
  esac

  if jpegoptim --strip-com --strip-iptc --strip-xmp --all-progressive --preserve -- "$input"; then
    log::info "optimized: $input"
  else
    log::error "optimize failed: $input"
    return 1
  fi
}

image::is_real_png() {
  local path="${1:?image::is_real_png requires a path}"
  file --mime-type -b "$path" 2> /dev/null | grep -qx 'image/png' || return 1
  pngcheck -q "$path" || return 1
}

# Validates a JPEG. If corrupt, moves it to a 'BAD_JPG' folder.
image::validate_jpeg() {
  local f="${1:?file required}"
  if image::is_real_jpeg "$f"; then
    return 0
  else
    log::warn "JPEG corrupt or invalid: $f"
    dir::create "BAD_JPG"
    file::move "$f" "BAD_JPG/$(basename -- "$f")"
    return 1
  fi
}

# Validates a PNG. If corrupt, moves it to a 'BAD_PNG' folder.
image::validate_png() {
  local f="${1:?file required}"
  if image::is_real_png "$f"; then
    return 0
  else
    log::warn "PNG corrupt or invalid: $f"
    dir::create "BAD_PNG"
    file::move "$f" "BAD_PNG/$(basename -- "$f")"
    return 1
  fi
}

image::optimize_png() {
  local input="${1:?image::optimize_png requires a file}"
  os::check_dependency pngquant pngcheck file || return 1
  file::is_readable "$input" || return 1
  image::is_real_png "$input" || {
    log::error "$input: not a valid PNG"
    return 1
  }

  local rc=0
  image::_archive_original ORIGINAL_PNG "$input" || rc=$?
  case $rc in
    0) ;;
    2)
      log::info "already optimized (original archived): $input"
      return 0
      ;;
    *) return 1 ;;
  esac

  if pngquant --speed 1 --force --strip --transbug --output "$input" -- "$input"; then
    log::info "optimized: $input"
  else
    log::error "optimize failed: $input"
    return 1
  fi
}

image::to_pdf() {
  local output="${1:?image::to_pdf requires OUTPUT}"
  shift
  (($# >= 1)) || {
    log::error "image::to_pdf requires at least 1 input image"
    return 1
  }
  os::check_dependency convert || return 1

  output=$(string::next_available_path "$output")
  log::info "converting $# images -> $output"

  # Strip EXIF/GPS/profiles so photo metadata never leaks into a PDF that gets
  # shared; -auto-orient first bakes in the EXIF rotation before the tag (and
  # the rest of the metadata) is removed, otherwise rotated photos go sideways.
  if convert "$@" -auto-orient -strip "$output"; then
    log::info "converted: $output"
  else
    log::error "conversion failed"
    rm -f -- "$output"
    return 1
  fi
}
