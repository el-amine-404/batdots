#!/usr/bin/env bash
# bin/linker.sh -- declarative symlink applier.
#
# Reads config/symlinks/<set>.conf line-by-line and creates / updates one
# symlink per row. Idempotent, collision-aware, and dry-run safe.
#
# Public API (set DRY_RUN=1 in the environment to preview without writes):
#   linker::link_item   <rel_src> <rel_dest> <perms>
#   linker::apply       <set>          # set name = filename without .conf
#   linker::audit       <set>          # report-only check (no changes), exit 1 if drift
set -Eeuo pipefail

linker::_run() {
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] $*"
  else
    "$@"
  fi
}

linker::link_item() {
  local rel_src="$1"
  local rel_dest="$2"
  local perms="$3"

  local src="${DOTFILES_ROOT}/${rel_src}"
  local dest="${HOME}/${rel_dest}"

  if [[ ! -e $src ]]; then
    log::warn "Source missing: $src (skipping)"
    return 1
  fi

  if [[ -n $perms ]]; then
    if [[ $perms =~ ^[0-7]{3,4}$ ]]; then
      if [[ -d $src ]]; then
        linker::_run find "$src" -type d -exec chmod "$perms" {} +
        linker::_run find "$src" -type f -name "*.sh" -exec chmod "$perms" {} +
        log::debug "  CHMOD: $perms -> $rel_src"
      else
        linker::_run chmod "$perms" "$src"
        log::debug "  CHMOD: $perms -> $rel_src"
      fi
    else
      log::error "Invalid permission format: '$perms' for $rel_src"
      log::error "Golden Rule: octal only (e.g. 600, 644, 755)"
      return 1
    fi
  fi

  linker::_run mkdir -p "$(dirname "$dest")"

  if [[ -L $dest ]]; then
    local current_target
    current_target=$(readlink -f "$dest")
    if [[ $current_target == "$src" ]]; then
      [[ -n $perms ]] && linker::_run chmod "$perms" "$src"
      log::debug "  OK: $rel_dest"
      return 0
    fi
  fi

  if [[ -d $dest && ! -L $dest ]]; then
    local backup
    backup="${dest}.backup.$(date +%s)"
    log::warn "Collision: '$rel_dest' is a real directory"
    log::warn "Moving it to: $(basename "$backup")"
    linker::_run mv "$dest" "$backup"
  fi

  linker::_run ln -sfn "$src" "$dest"
  log::info "LINK: $rel_dest -> $rel_src"
}

linker::apply() {
  local set="$1"
  local manifest_file="${DOTFILES_ROOT}/config/symlinks/${set}.conf"
  if [[ ! -f $manifest_file ]]; then
    log::fatal "symlink conf not found: $manifest_file"
  fi

  local tag=""
  [[ ${DRY_RUN:-0} == 1 ]] && tag=" (dry-run)"
  log::info "Applying symlink conf: $(basename "$manifest_file")${tag}"

  while IFS='|' read -r raw_src raw_dest raw_perm || [[ -n $raw_src ]]; do
    local src dest perm
    src=$(echo "$raw_src" | xargs)
    dest=$(echo "$raw_dest" | xargs)
    perm=$(echo "${raw_perm:-}" | xargs)

    [[ $src =~ ^#.*$ ]] && continue
    [[ -z $src ]] && continue

    linker::link_item "$src" "$dest" "$perm" || true
  done < "$manifest_file"
}

# Report-only: walks a manifest and counts entries that are missing, broken,
# or pointing somewhere unexpected. Exits non-zero if anything is wrong.
# Used by bin/doctor.sh.
linker::audit() {
  local set="$1"
  local manifest_file="${DOTFILES_ROOT}/config/symlinks/${set}.conf"
  if [[ ! -f $manifest_file ]]; then
    log::error "audit: manifest missing: $manifest_file"
    return 1
  fi

  local total=0 ok=0 missing_src=0 wrong_target=0 not_link=0 absent=0
  while IFS='|' read -r raw_src raw_dest _ || [[ -n $raw_src ]]; do
    local src dest
    src=$(echo "$raw_src" | xargs)
    dest=$(echo "$raw_dest" | xargs)
    [[ $src =~ ^#.*$ ]] && continue
    [[ -z $src ]] && continue
    total=$((total + 1))

    local abs_src="${DOTFILES_ROOT}/${src}"
    local abs_dest="${HOME}/${dest}"

    if [[ ! -e $abs_src ]]; then
      log::warn "  src missing: $src"
      missing_src=$((missing_src + 1))
      continue
    fi

    if [[ ! -e $abs_dest && ! -L $abs_dest ]]; then
      log::warn "  dest absent: $dest"
      absent=$((absent + 1))
      continue
    fi

    if [[ ! -L $abs_dest ]]; then
      log::warn "  dest is not a symlink: $dest"
      not_link=$((not_link + 1))
      continue
    fi

    local target
    target=$(readlink -f -- "$abs_dest")
    if [[ $target != "$abs_src" ]]; then
      log::warn "  wrong target: $dest -> $target (expected $abs_src)"
      wrong_target=$((wrong_target + 1))
      continue
    fi

    ok=$((ok + 1))
  done < "$manifest_file"

  log::info "[$set] total=$total ok=$ok absent=$absent wrong=$wrong_target collision=$not_link missing-src=$missing_src"
  ((absent + wrong_target + not_link + missing_src == 0))
}
