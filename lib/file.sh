#!/usr/bin/env bash
file::exists() { [[ -e ${1:-} ]] || {
  log::error "missing: ${1:-}"
  return 1
}; }
file::is_regular() { [[ -f ${1:-} ]] || {
  log::error "not a file: ${1:-}"
  return 1
}; }
file::is_directory() { [[ -d ${1:-} ]] || {
  log::error "not a dir: ${1:-}"
  return 1
}; }
file::is_readable() { [[ -r ${1:-} ]] || {
  log::error "not readable: ${1:-}"
  return 1
}; }
file::is_writable() { [[ -w ${1:-} ]] || {
  log::error "not writable: ${1:-}"
  return 1
}; }
file::is_executable() { [[ -x ${1:-} ]] || {
  log::error "not executable: ${1:-}"
  return 1
}; }
file::is_not_empty() { [[ -s ${1:-} ]] || {
  log::error "empty: ${1:-}"
  return 1
}; }

# -- Name introspection ------------------------------------------------------
# Pure string getters: they parse a path's final component and never touch the
# filesystem. A leading dot marks a hidden file (.bashrc), not an extension, so
# these treat it as part of the name -- unlike a naive '${x##*.}'.
#
# For "/foo/bar/example.tar.gz" the four views are:
#   file::extension       gz        (last extension only)      ${name##*.}
#   file::extension_full  tar.gz    (whole compound extension)  ${rest#*.}
#   file::stem            example.tar  (drop the last extension) ${name%.*}
#   file::name            example   (drop every extension)      ${rest%%.*}

# Last extension, without the dot ("gz"); empty if the name has none.
file::extension() {
  local name="${1##*/}"
  [[ ${name#.} == *.* ]] || return 0
  printf '%s' "${name##*.}"
}

# Full compound extension ("tar.gz"); empty if the name has none.
file::extension_full() {
  local name="${1##*/}" rest="${1##*/}"
  rest="${name#.}"
  [[ $rest == *.* ]] || return 0
  printf '%s' "${rest#*.}"
}

# Final component with the last extension removed ("example.tar").
file::stem() {
  local name="${1##*/}"
  [[ ${name#.} == *.* ]] && printf '%s' "${name%.*}" || printf '%s' "$name"
}

# Final component with every extension removed ("example"), keeping a leading
# dot for hidden files (".config.json" -> ".config").
file::name() {
  local name="${1##*/}" rest="${1##*/}" lead=""
  rest="${name#.}"
  [[ $rest == *.* ]] || {
    printf '%s' "$name"
    return 0
  }
  [[ $name == .* ]] && lead="."
  printf '%s' "${lead}${rest%%.*}"
}

# Read KEY=VALUE (or any DELIMITER) from a config file. Returns the value via
# stdout, or non-zero if the key isn't found. Handles quoted values and # comments.
file::get_config_value() {
  local file="${1:-}" target="${2:-}" delimiter="${3:-=}"
  [[ -z $file || -z $target ]] && {
    log::error "file::get_config_value requires FILE KEY"
    return 1
  }
  [[ -f $file ]] || return 1

  local line key value
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ -z $line || $line != *"$delimiter"* ]] && continue

    key="${line%%"$delimiter"*}"
    value="${line#*"$delimiter"}"
    key="$(string::trim "$key")"

    [[ $key != "$target" ]] && continue

    value="$(string::trim "$value")"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s' "$value"
    return 0
  done < "$file"
  return 1
}

file::move() {
  local src="${1:-}" dst="${2:-}"
  [[ -z $src || -z $dst ]] && {
    log::error "file::move requires SRC DST"
    return 1
  }
  file::exists "$src" || return 1
  if [[ $src == "$dst" ]]; then
    # No warning here, we handle this in the transformation wrapper
    return 0
  fi
  [[ -d $dst ]] && dst="${dst%/}/$(basename -- "$src")"
  local dst_dir
  dst_dir=$(dirname -- "$dst")
  [[ -d $dst_dir ]] || {
    log::error "destination dir missing: $dst_dir"
    return 1
  }

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[DRY-RUN] mv -- \"$src\" \"$dst\""
    return 0
  fi

  # Log for undo if requested
  if [[ -n "${UNDO_SCRIPT_PATH:-}" ]]; then
    printf 'mv --backup=t -- %q %q\n' "$dst" "$src" >> "$UNDO_SCRIPT_PATH"
  fi

  mv --backup=t -- "$src" "$dst"
}

file::copy() {
  local src="${1:-}" dst="${2:-}"
  [[ -z $src || -z $dst ]] && {
    log::error "file::copy requires SRC DST"
    return 1
  }
  file::exists "$src" || return 1
  [[ $src == "$dst" ]] && {
    log::warn "src and dst identical, skipping: $src"
    return 0
  }
  local dst_dir
  dst_dir=$(dirname -- "$dst")
  [[ -d $dst_dir ]] || {
    log::error "destination dir missing: $dst_dir"
    return 1
  }

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[DRY-RUN] cp --preserve=mode,timestamps --backup=t -- \"$src\" \"$dst\""
    return 0
  fi

  # Preserve mode and timestamps so backups and archived originals keep the
  # source's metadata; deliberately not ownership, which would make a
  # non-root copy of a root-owned file fail on the chown.
  cp --preserve=mode,timestamps --backup=t -- "$src" "$dst"
}

file::remove() {
  local path="${1:-}"
  [[ -z $path ]] && {
    log::error "file::remove requires PATH"
    return 1
  }
  file::exists "$path" || return 1

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[DRY-RUN] rm -- \"$path\""
    return 0
  fi

  rm -- "$path"
}

_file::split_name() {
  local name="$1" kind base ext_raw=""
  case "$name" in
    . | ..)
      log::error "not a normal node: $name"
      return 1
      ;;
    .*)
      local rest="${name#.}"
      if [[ $rest == *.* ]]; then
        kind="hidden-with-exts"
        base="${rest%%.*}"
        ext_raw="${rest#*.}"
      else
        kind="hidden-no-ext"
        base="$rest"
      fi
      ;;
    *.*)
      if [[ "${name#*.}" != "${name##*.}" ]]; then
        kind="multiple-dots"
        base="${name%%.*}"
        ext_raw="${name#*.}"
      else
        kind="single-dot"
        base="${name%.*}"
        ext_raw="${name##*.}"
      fi
      ;;
    *)
      kind="no-ext"
      base="$name"
      ;;
  esac
  printf '%s|%s|%s' "$kind" "$base" "$ext_raw"
}

_file::ascii_sanitize() {
  local mode="$1" s="$2"
  case "$mode" in
    base)
      printf '%s' "$s" \
        | iconv -f UTF-8 -t ASCII//TRANSLIT 2> /dev/null \
        | LC_ALL=C tr -c 'a-zA-Z0-9-' '_' \
        | LC_ALL=C sed -e 's/__*/_/g' -e 's/^[-_]*//' -e 's/[-_]*$//'
      ;;
    ext)
      printf '%s' "$s" \
        | iconv -f UTF-8 -t ASCII//TRANSLIT 2> /dev/null \
        | LC_ALL=C tr -c 'a-zA-Z0-9.' '_' \
        | LC_ALL=C sed -e 's/__*/_/g' -e 's/^\.*//' -e 's/\.*$//'
      ;;
  esac
}

_file::rename_with_transform() {
  local mode="$1" path="$2"
  file::exists "$path" || return 1
  command -v iconv &> /dev/null || {
    log::error "iconv required"
    return 1
  }

  local dir name
  dir=$(dirname -- "$path")
  name=$(basename -- "$path")
  local split kind base ext
  split=$(_file::split_name "$name") || return 1
  IFS='|' read -r -d '' kind base ext < <(printf "%s" "$split") || :

  local new_base new_ext
  case "$mode" in
    lowercase) new_base=$(printf '%s' "$base" | LC_ALL=C tr '[:upper:]' '[:lower:]') ;;
    uppercase) new_base=$(printf '%s' "$base" | LC_ALL=C tr '[:lower:]' '[:upper:]') ;;
    sanitize) new_base=$(_file::ascii_sanitize base "$base") ;;
    sanitize-lowercase)
      new_base=$(_file::ascii_sanitize base "$base")
      new_base=$(printf '%s' "$new_base" | LC_ALL=C tr '[:upper:]' '[:lower:]')
      ;;
    sanitize-uppercase)
      new_base=$(_file::ascii_sanitize base "$base")
      new_base=$(printf '%s' "$new_base" | LC_ALL=C tr '[:lower:]' '[:upper:]')
      ;;
    *)
      log::error "_file::rename_with_transform: unknown mode '$mode'"
      return 1
      ;;
  esac

  # Fallback for names that become empty after sanitization
  [[ -z $new_base ]] && new_base="unnamed"

  if [[ -n $ext ]]; then
    new_ext=$(_file::ascii_sanitize ext "$ext")
    # Extensions follow the case of the base for compound modes
    case "$mode" in
      lowercase | sanitize-lowercase) new_ext=$(printf '%s' "$new_ext" | LC_ALL=C tr '[:upper:]' '[:lower:]') ;;
      uppercase | sanitize-uppercase) new_ext=$(printf '%s' "$new_ext" | LC_ALL=C tr '[:lower:]' '[:upper:]') ;;
    esac
  fi

  local new_name
  case "$kind" in
    hidden-no-ext) new_name=".${new_base}" ;;
    hidden-with-exts) new_name=".${new_base}${new_ext:+.$new_ext}" ;;
    single-dot | multiple-dots) new_name="${new_base}${new_ext:+.$new_ext}" ;;
    *) new_name="$new_base" ;;
  esac

  if [[ $name != "$new_name" ]]; then
    local target="${dir}/${new_name}"

    # Prevent collision with existing files
    target="$(string::next_available_path "$target")"
    new_name="$(basename -- "$target")"

    if [[ ${INTERACTIVE_RENAME:-0} == 1 ]]; then
      confirmation::seek "Rename '${name}' -> '${new_name}'?"
      confirmation::is_confirmed || return 2
    fi

    log::info "${mode}: '${name}' -> '${new_name}'"
    file::move "$path" "$target"
    return 0
  fi
  return 2
}

file::to_lowercase_name() { _file::rename_with_transform lowercase "${1:-}"; }
file::to_uppercase_name() { _file::rename_with_transform uppercase "${1:-}"; }
file::sanitize_name() { _file::rename_with_transform sanitize "${1:-}"; }
file::sanitize_and_lowercase_name() { _file::rename_with_transform sanitize-lowercase "${1:-}"; }
file::sanitize_and_uppercase_name() { _file::rename_with_transform sanitize-uppercase "${1:-}"; }

file::compress() {
  local input="${1:?file::compress requires INPUT_PATH}"
  local output="${2:?file::compress requires OUTPUT_FILE}"

  command -v tar &> /dev/null || {
    log::error "tar required"
    return 1
  }
  command -v xz &> /dev/null || {
    log::error "xz required"
    return 1
  }
  file::exists "$input" || return 1
  file::is_readable "$input" || return 1

  local out_dir
  out_dir=$(dirname -- "$output")
  [[ -d $out_dir ]] || {
    log::error "output dir missing: $out_dir"
    return 1
  }

  output=$(string::next_available_path "$output")
  local cores
  cores=$(nproc)
  local threads=$((cores > 1 ? cores - 1 : 1))
  local parent base
  parent=$(dirname -- "$input")
  base=$(basename -- "$input")

  log::info "compressing '$input' -> '$output'"
  tar -C "$parent" \
    --use-compress-program="xz -T ${threads} -9 --memlimit=2GiB" \
    -cf "$output" -- "$base" \
    || {
      log::error "compress failed"
      return 1
    }
}

file::decompress() {
  local archive="${1:?file::decompress requires an archive}"
  command -v tar &> /dev/null || {
    log::error "tar required"
    return 1
  }
  file::is_regular "$archive" || return 1
  file::is_readable "$archive" || return 1

  local name parent
  name=$(basename -- "$archive")
  case "$name" in
    *.tar.*) parent="${name%%.tar.*}" ;;
    *.tar) parent="${name%.tar}" ;;
    *) parent="${name%.*}" ;;
  esac
  [[ -z $parent ]] && parent="archive"
  parent=$(string::next_available_path "$parent")

  mkdir -p -- "$parent"
  log::info "decompressing '$archive' -> '$parent'"
  tar -C "$parent" -xf "$archive" \
    || {
      log::error "decompress failed"
      return 1
    }
}

# Replace placeholders in a file with actual values.
# Placeholders should be in the format __KEY__
# Usage: file::render_template <template_path> <output_path> <key1=val1> <key2=val2> ...
file::render_template() {
  local template="${1:?template required}"
  local output="${2:?output required}"
  shift 2

  [[ -f $template ]] || {
    log::error "template not found: $template"
    return 1
  }

  local content
  content=$(< "$template")

  local pair key val
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    # Escape special characters for sed (specifically | which we use as delimiter)
    val="${val//|/\\|}"
    content=$(sed "s|__${key}__|${val}|g" <<< "$content")
  done

  printf '%s\n' "$content" > "$output"
}

file::rename_sequential() {
  local i=1
  if [[ ${1:-} == --start ]]; then
    i="${2:?file::rename_sequential --start requires a number}"
    shift 2
  fi
  local pattern="${1:?file::rename_sequential requires PATTERN (e.g. %03d_art.jpg)}"
  shift
  (($# >= 1)) || {
    log::error "file::rename_sequential requires at least 1 file"
    return 1
  }

  local f ext new_name
  for f in "$@"; do
    [[ -e $f ]] || continue
    ext="${f##*.}"
    # If the pattern doesn't contain an extension, we append the original one
    if [[ $pattern != *.* ]]; then
      new_name=$(printf "${pattern}.${ext}" "$i")
    else
      new_name=$(printf "$pattern" "$i")
    fi
    log::info "renaming: $f -> $new_name"
    file::move "$f" "$new_name"
    ((i++))
  done
}

# Prepend content to a file safely.
# Usage: file::prepend <file_path> <content>
file::prepend() {
  local file="${1:?file::prepend requires FILE}"
  local content="${2:?file::prepend requires CONTENT}"
  file::is_regular "$file" || return 1

  local tmp_file=$(mktemp)
  {
    printf '%s\n' "$content"
    cat "$file"
  } > "$tmp_file"

  mv "$tmp_file" "$file"
}

# Check if a file starts with a specific header string.
# Usage: file::has_header <file_path> <header_string>
file::has_header() {
  local file="${1:?file::has_header requires FILE}"
  local header="${2:?file::has_header requires HEADER}"
  file::is_regular "$file" || return 1
  [[ $(head -n 1 "$file") == "$header"* ]]
}

# Get file modification date in local ISO 8601 format (YYYY-MM-DDTHH:MM:SS+HH:MM).
file::modification_date() {
  local file="${1:?file::modification_date requires FILE}"
  file::exists "$file" || return 1

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    date --iso-8601=seconds -r "$file"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS local time with offset
    stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%S%z" "$file"
  else
    date +"%Y-%m-%dT%H:%M:%S%z"
  fi
}

# Get file birth time in local ISO 8601 format (YYYY-MM-DDTHH:MM:SS+HH:MM).
# Returns non-zero with no output when the filesystem doesn't expose btime
# (ecryptfs, tmpfs, NFS, FUSE, ext4 on kernels < 4.11). Callers decide what to
# do with the absence -- the lib intentionally does not synthesize a value.
file::creation_date() {
  local file="${1:?file::creation_date requires FILE}"
  file::exists "$file" || return 1

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    local btime
    btime=$(stat -c %W -- "$file" 2> /dev/null) || return 1
    [[ $btime =~ ^[0-9]+$ ]] || return 1
    ((btime > 0)) || return 1
    date --iso-8601=seconds -d "@$btime"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    local out
    out=$(stat -f "%SB" -t "%Y-%m-%dT%H:%M:%S%z" -- "$file" 2> /dev/null) || return 1
    [[ -n $out ]] || return 1
    printf '%s' "$out"
  else
    return 1
  fi
}
