#!/usr/bin/env bash
# Robust wrapper around tar/xz for archiving directories with exclusions.
# Handles thread detection, resource prioritization, and error reporting.
#
# Usage: archive::compress <input_dir> <output_file> [exclusion1] [exclusion2] ...
archive::compress() {
  local input="${1:?archive::compress requires INPUT_DIR}"
  local output="${2:?archive::compress requires OUTPUT_FILE}"
  shift 2
  local exclusions=("$@")

  os::check_dependency "tar" || return 1
  os::check_dependency "xz" || return 1

  if [[ ! -d $input ]]; then
    log::error "Archive target is not a directory: $input"
    return 1
  fi

  local parent base
  parent=$(dirname -- "$(readlink -f -- "$input")")
  base=$(basename -- "$input")

  local cores
  cores=$(nproc)
  # Leave some headroom for the system
  local threads=$((cores > 2 ? cores - 2 : 1))

  local tar_args=(
    "-C" "$parent"
    "--use-compress-program=xz -T ${threads} -6 --memlimit=1GiB"
    "-cf" "$output"
  )

  local ex
  for ex in "${exclusions[@]}"; do
    tar_args+=("--exclude=$ex")
  done

  tar_args+=("--" "$base")

  log::info "Archiving '$base' to '$output' (${threads} threads)..."

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[DRY-RUN] tar ${tar_args[*]}"
    return 0
  fi

  # Run with low priority to avoid system lag
  nice -n 19 ionice -c2 -n7 tar "${tar_args[@]}" || {
    log::error "Archiving failed for $base"
    return 1
  }

  archive::verify "$output" || return 1

  log::info "Successfully created: $(basename -- "$output")"
}

# Test the integrity of an xz-compressed archive. Cheap enough to run on
# every write so a silent corruption (bad block, full disk caught late)
# is reported instead of declared "successful".
archive::verify() {
  local output="${1:?archive::verify requires OUTPUT_FILE}"
  [[ ${DRY_RUN:-0} == 1 ]] && return 0
  os::check_dependency "xz" || return 1

  if ! xz -t -- "$output" 2> /dev/null; then
    log::error "Archive failed integrity check: $output"
    return 1
  fi
  log::debug "Archive integrity OK: $(basename -- "$output")"
}

# High-level orchestrator: validate the target, run the framework gate,
# detect every applicable tag, union their exclusion sets, and archive.
# Exclusions are NOT caller-owned anymore -- they live in lib/project.sh
# under PROJECT_EXCLUDES_<TAG> so a Spring Boot + Webpack + Node project
# gets java + maven + node + webpack excludes merged automatically.
#
# Usage: archive::project <gate_fn> [target]
#   gate_fn -- e.g. project::is_java; the script's identity check.
#             Pass project::is_any to skip the gate.
#   target  -- directory to archive (default: $PWD)
#
# Output: ../<basename>.tar.xz (next-available variant if it exists).
# Returns 0 even when the gate rejects -- non-matches are a skip, not a
# failure, so recursive walkers don't abort on the first miss.
archive::project() {
  local gate="${1:?archive::project requires GATE_FN}"
  local target="${2:-$PWD}"

  local resolved
  resolved=$(project::resolve_target "$target") || return 1

  if ! "$gate" "$resolved"; then
    log::warn "not a matching project, skipping: $target"
    return 0
  fi

  project::detect_tags "$resolved"
  project::union_excludes "${PROJECT_DETECTED_TAGS[@]}"
  log::info "tags: ${PROJECT_DETECTED_TAGS[*]:-none}"

  local parent base output
  parent=$(dirname -- "$resolved")
  base=$(basename -- "$resolved")
  output=$(string::next_available_path "${parent}/${base}.tar.xz")

  archive::compress "$resolved" "$output" "${PROJECT_UNIONED_EXCLUDES[@]}"
}
