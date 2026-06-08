#!/usr/bin/env bash
# scripts/user/add-yaml-front-matter.sh -- Add YAML front matter to Markdown files.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

FM_TARGET="."
FM_USER_TAGS=""
FM_USER_AUTHOR=""
FM_USER_DATE=""
FM_SYNC_TITLE=0
FM_PROBE_BTIME=1
FM_PROBE_DISABLED=0
FM_STATS_ADDED=0
FM_STATS_SYNCED=0
FM_STATS_SKIPPED=0

fm::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY|FILE]

Recursively adds YAML front matter to Markdown files. Existing front matter is
preserved -- only the 'updated' field is refreshed (and 'title' with --sync-title).
File mtime is restored after each write so the script is idempotent.

Options:
  -t, --tags "a, b"     Custom tags (default: untagged)
  -a, --author NAME     Override author (env: \$DOTFILES_AUTHOR, fallback: \$USER)
  -D, --date ISO        Force 'date' field for NEW front matter (ISO 8601)
  -s, --sync-title      Refresh 'title' from filename on existing files
  -n, --dry-run         Show what would change without writing
  -P, --no-probe        Don't probe btime via 'sudo debugfs' when statx is blind
  -h, --help            Show this help message

When the filesystem doesn't expose birth time (ecryptfs, tmpfs, NFS, ...) the
script tries 'sudo debugfs' against the underlying block device to recover it.
This prompts for sudo on the first file; pass --no-probe to skip entirely.
EOF
}

fm::parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n | --dry-run) export DRY_RUN=1 ;;
      -t | --tags)
        shift
        FM_USER_TAGS="${1:-}"
        ;;
      -a | --author)
        shift
        FM_USER_AUTHOR="${1:-}"
        ;;
      -D | --date)
        shift
        FM_USER_DATE="${1:-}"
        ;;
      -s | --sync-title) FM_SYNC_TITLE=1 ;;
      -P | --no-probe) FM_PROBE_BTIME=0 ;;
      -h | --help)
        fm::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        fm::usage >&2
        exit 1
        ;;
      *) FM_TARGET="$1" ;;
    esac
    shift
  done
}

fm::resolve_author() {
  if [[ -n $FM_USER_AUTHOR ]]; then
    printf '%s' "$FM_USER_AUTHOR"
  elif [[ -n ${DOTFILES_AUTHOR:-} ]]; then
    printf '%s' "$DOTFILES_AUTHOR"
  else
    printf '%s' "${USER:-Anonymous}"
  fi
}

fm::normalize_tags() {
  local raw="${1:-}"
  [[ -z $raw ]] && return 0
  printf '%s' "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ',' '\n' \
    | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//' \
    | grep -v '^$' \
    | sort -u
}

fm::format_title() {
  local file="$1" name
  name=$(basename -- "$file" .md)
  printf '%s' "$name" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/ /g; s/^ +//; s/ +$//'
}

fm::restore_mtime() {
  local file="$1" mtime="$2"
  [[ ${DRY_RUN:-0} == 1 ]] && return 0
  if [[ $OSTYPE == linux-gnu* ]]; then
    touch -d "$mtime" -- "$file"
  else
    local stamp
    stamp=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$mtime" "+%Y%m%d%H%M.%S")
    touch -t "$stamp" -- "$file"
  fi
}

fm::has_front_matter() {
  local file="$1"
  awk '
    NR == 1 {
      sub(/\r$/, "")
      if ($0 !~ /^---[[:space:]]*$/) exit 1
      in_fm = 1
      next
    }
    in_fm {
      sub(/\r$/, "")
      if ($0 ~ /^---[[:space:]]*$/) { found = 1; exit }
    }
    END { exit (found ? 0 : 1) }
  ' < "$file"
}

fm::get_field() {
  local file="$1" key="$2"
  awk -v k="$key" '
    { sub(/\r$/, "") }
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/   { exit }
    in_fm && $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", "")
      sub(/[[:space:]]+$/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' < "$file"
}

fm::generate_yaml() {
  local title="$1" author="$2" date="$3" updated="$4" tags_raw="$5"
  local date_line="date:"
  [[ -n $date ]] && date_line="date: $date"
  cat << EOF
---
title: "$title"
author:
  - "$author"
$date_line
updated: $updated
tags:
EOF

  local has_tag=0 tag
  while IFS= read -r tag; do
    [[ -z $tag ]] && continue
    printf '  - "%s"\n' "$tag"
    has_tag=1
  done < <(fm::normalize_tags "$tags_raw")
  ((has_tag == 0)) && printf '  - "untagged"\n'

  cat << 'EOF'
summary: ""
status: draft
---

EOF
}

fm::sync_existing() {
  local file="$1" updated="$2"
  local current_updated current_title new_title=""

  current_updated=$(fm::get_field "$file" "updated")

  if ((FM_SYNC_TITLE == 1)); then
    current_title=$(fm::get_field "$file" "title")
    new_title=$(fm::format_title "$file")
  fi

  if [[ $current_updated == "$updated" ]] \
    && { ((FM_SYNC_TITLE == 0)) || [[ ${current_title:-} == "$new_title" ]]; }; then
    ((FM_STATS_SKIPPED++)) || true
    log::debug "Already in sync: $file"
    return 0
  fi

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[DRY-RUN] Would sync metadata: $file"
    ((FM_STATS_SYNCED++)) || true
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  awk -v new_updated="$updated" \
    -v sync_title="$FM_SYNC_TITLE" \
    -v new_title="$new_title" '
    { sub(/\r$/, "") }
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }
    in_fm && /^---[[:space:]]*$/ {
      if (!seen_updated) print "updated: " new_updated
      in_fm = 0
      print
      next
    }
    in_fm && /^updated:[[:space:]]/ {
      print "updated: " new_updated
      seen_updated = 1
      next
    }
    in_fm && sync_title == "1" && /^title:[[:space:]]/ {
      print "title: \"" new_title "\""
      next
    }
    { print }
  ' < "$file" > "$tmp"

  mv -- "$tmp" "$file"
  ((FM_STATS_SYNCED++)) || true
  log::info "Synced metadata: $file"
}

fm::add_new() {
  local file="$1" date="$2" updated="$3"
  local title author header
  title=$(fm::format_title "$file")
  author=$(fm::resolve_author)

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[DRY-RUN] Would add front matter: $file (date=$date updated=$updated)"
    ((FM_STATS_ADDED++)) || true
    return 0
  fi

  header=$(fm::generate_yaml "$title" "$author" "$date" "$updated" "$FM_USER_TAGS")
  file::prepend "$file" "$header"
  ((FM_STATS_ADDED++)) || true
  log::info "Added front matter: $file"
}

# Locate the debugfs binary. It usually lives in /usr/sbin or /sbin, which
# aren't always on a non-root user's PATH -- so we also check explicit paths.
fm::find_debugfs() {
  local cand
  for cand in debugfs /usr/sbin/debugfs /sbin/debugfs; do
    if command -v "$cand" &> /dev/null; then
      command -v "$cand"
      return 0
    fi
    [[ -x $cand ]] && {
      printf '%s' "$cand"
      return 0
    }
  done
  return 1
}

# Walk up stacked mounts (e.g. ecryptfs over ext4) to the underlying block
# device. Emits the device path on stdout, returns non-zero if we can't reach
# a block device within 4 levels.
fm::resolve_block_device() {
  local path="$1" source="" hops=0
  while ((hops < 4)); do
    source=$(findmnt -no source -T "$path" 2> /dev/null) || return 1
    [[ -n $source ]] || return 1
    [[ -b $source ]] && {
      printf '%s' "$source"
      return 0
    }
    path="$source"
    ((hops++))
  done
  return 1
}

# Recover btime from an ext-family inode via debugfs when statx can't see it
# (ecryptfs, kernels lacking statx propagation). Automates the manual recipe:
#   inode=$(stat -c %i FILE)
#   device=$(findmnt -no source -T "$(findmnt -no source -T FILE)")
#   sudo debugfs -R "stat <$inode>" "$device"   # then read the 'crtime:' line
# Uses interactive sudo so the user can authenticate on first call; credentials
# are then cached by sudo for ~5min so a batch run only prompts once. Sets
# FM_PROBE_DISABLED on any unrecoverable failure so we don't retry the rest of
# the run (no point prompting again for the same blocked operation).
fm::probe_btime_via_debugfs() {
  local file="$1"

  ((FM_PROBE_BTIME == 1)) || return 1
  ((FM_PROBE_DISABLED == 1)) && return 1

  local debugfs_bin
  debugfs_bin=$(fm::find_debugfs) || {
    log::warn "btime probe disabled: debugfs not installed (apt install e2fsprogs)"
    FM_PROBE_DISABLED=1
    return 1
  }
  command -v findmnt &> /dev/null || {
    log::warn "btime probe disabled: findmnt not installed (apt install util-linux)"
    FM_PROBE_DISABLED=1
    return 1
  }
  command -v sudo &> /dev/null || {
    log::warn "btime probe disabled: sudo not installed"
    FM_PROBE_DISABLED=1
    return 1
  }

  local device fstype inode
  device=$(fm::resolve_block_device "$file") || {
    log::debug "$file: no underlying block device -- skipping debugfs probe"
    return 1
  }
  fstype=$(findmnt -no fstype "$device" 2> /dev/null) || return 1
  [[ $fstype =~ ^ext[234]$ ]] || {
    log::debug "$file: $device is $fstype, debugfs supports ext{2,3,4} only"
    return 1
  }
  inode=$(stat -c %i -- "$file" 2> /dev/null) || return 1
  [[ $inode =~ ^[0-9]+$ ]] || return 1

  log::info "probing btime via: sudo $debugfs_bin -R 'stat <$inode>' $device"

  local raw_output
  raw_output=$(sudo "$debugfs_bin" -R "stat <$inode>" "$device" 2> /dev/null) || {
    log::warn "btime probe disabled: sudo $debugfs_bin failed (auth cancelled or no permission)"
    FM_PROBE_DISABLED=1
    return 1
  }

  # crtime line: " crtime: 0x6a0a427f:b247e8d4 -- Sun May 17 23:34:39 2026"
  local hex
  hex=$(printf '%s' "$raw_output" | awk '/^[[:space:]]*crtime:/ {print $2; exit}')
  [[ $hex =~ ^0x[0-9a-fA-F]+ ]] || {
    log::warn "$file: debugfs returned no crtime field for inode $inode"
    return 1
  }

  local epoch
  epoch=$((${hex%%:*}))
  ((epoch > 0)) || return 1
  date --iso-8601=seconds -d "@$epoch" 2> /dev/null
}

# Priority chain: --date override -> fs btime (statx) -> ext debugfs probe -> empty.
# Empty means "leave the date field blank" -- never falls back to mtime.
fm::resolve_origin_date() {
  local file="$1" out

  if [[ -n $FM_USER_DATE ]]; then
    printf '%s' "$FM_USER_DATE"
    return 0
  fi

  if out=$(file::creation_date "$file" 2> /dev/null); then
    printf '%s' "$out"
    return 0
  fi

  if out=$(fm::probe_btime_via_debugfs "$file"); then
    log::debug "$file: btime recovered via debugfs"
    printf '%s' "$out"
    return 0
  fi

  log::debug "$file: no btime available -- leaving date empty"
  printf ''
}

fm::apply_to_file() {
  local file="$1"
  if [[ ! -f $file ]]; then
    log::warn "Skipping (not a regular file): $file"
    return 0
  fi

  local original_mtime resolved_date
  original_mtime=$(file::modification_date "$file") || return 0

  if fm::has_front_matter "$file"; then
    fm::sync_existing "$file" "$original_mtime"
  else
    resolved_date=$(fm::resolve_origin_date "$file")
    fm::add_new "$file" "$resolved_date" "$original_mtime"
  fi

  [[ ${DRY_RUN:-0} == 1 ]] || fm::restore_mtime "$file" "$original_mtime"
}

fm::process_directory() {
  local dir="$1"
  while IFS= read -r -d '' file; do
    fm::apply_to_file "$file"
  done < <(find "$dir" -type f -name '*.md' \
    -not -path '*/.*' \
    -not -path '*/node_modules/*' \
    -print0)
}

fm::print_summary() {
  log::info "Summary: added=${FM_STATS_ADDED} synced=${FM_STATS_SYNCED} skipped=${FM_STATS_SKIPPED}"
}

main() {
  fm::parse_arguments "$@"
  banner::print "YAML Front Matter"

  if [[ -f $FM_TARGET ]]; then
    fm::apply_to_file "$FM_TARGET"
  elif [[ -d $FM_TARGET ]]; then
    fm::process_directory "$FM_TARGET"
  else
    log::error "Target does not exist: $FM_TARGET"
    exit 1
  fi

  fm::print_summary
}

main "$@"
