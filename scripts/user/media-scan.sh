#!/usr/bin/env bash
# Incremental malware scanner for the homelab media/download tree.
#
# Designed for TB-scale libraries: it scans only NEW files (since the last run)
# or the explicit paths it is handed -- it never re-scans the whole library.
#
# Per file it runs three cheap, size-independent checks plus AV:
#   1. dangerous extension       (.exe/.scr/.js/.lnk/... hiding among media)
#   2. executable content        (a "movie.mp4" whose bytes are really a PE/ELF)
#   3. ClamAV signatures         (clamdscan if the daemon is up, else clamscan)
#   4. YARA rules                (optional, if DOTFILES_MEDIA_SCAN_YARA is set)
#
# Hits are MOVED to quarantine (never deleted) and reported via Pushover.
#
# Usage:
#   media-scan.sh                 # incremental: files changed since last run
#   media-scan.sh --all           # full sweep of all configured paths
#   media-scan.sh <path> [...]    # scan specific files/dirs (used by the watcher)

set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# -- Config (override in local/env.sh) ---------------------------------------
declare -a SCAN_PATHS
if [[ -n ${DOTFILES_MEDIA_SCAN_PATHS+x} ]]; then
  SCAN_PATHS=("${DOTFILES_MEDIA_SCAN_PATHS[@]}")
elif [[ -n ${DOTFILES_HOMELAB_DATA_ROOT:-} ]]; then
  SCAN_PATHS=("$DOTFILES_HOMELAB_DATA_ROOT")
else
  SCAN_PATHS=()
fi

QUARANTINE="${DOTFILES_MEDIA_SCAN_QUARANTINE:-${DOTFILES_HOMELAB_DATA_ROOT:-$HOME}/.quarantine}"
STATE_FILE="${DOTFILES_MEDIA_SCAN_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/media-scan.last}"
YARA_RULES="${DOTFILES_MEDIA_SCAN_YARA:-}"

# Extensions that have no business in a media tree.
DANGEROUS_EXT_RE='^(exe|scr|bat|cmd|com|pif|msi|js|jse|vbs|vbe|ps1|psm1|jar|lnk|sh|bin|run|app|dll|sys|reg|hta|wsf|cpl|gadget|sct)$'
# Content types that mean "this is a program", whatever the extension claims.
EXEC_MIME_RE='(x-dosexec|x-executable|x-pie-executable|x-elf|x-sharedlib|x-mach-binary|x-msdownload|portable-executable|x-shellscript|x-msdos-batch|x-ms-shortcut)'
# Incomplete-download artefacts to ignore.
SKIP_NAME_RE='\.(part|!qB|!ut|tmp|crdownload|partial)$'

ENGINE=""             # clamdscan | clamscan | "" (none)
declare -a THREATS=() # human-readable "path  ->  reason" lines
SCANNED=0

ms::resolve_engine() {
  if command -v clamdscan > /dev/null 2>&1 \
    && systemctl is-active --quiet clamav-daemon 2> /dev/null; then
    ENGINE="clamdscan"
  elif command -v clamscan > /dev/null 2>&1; then
    ENGINE="clamscan"
  else
    log::warn "ClamAV not available -- relying on extension/content checks only."
  fi
}

# Echo the ClamAV signature name if infected; return 1 if infected, 0 if clean,
# 2 on scanner error (treated as inconclusive, not a block).
ms::clam_check() {
  local file="$1" out rc
  [[ -z $ENGINE ]] && return 0
  out=$("$ENGINE" --no-summary --infected -- "$file" 2> /dev/null) && rc=0 || rc=$?
  if [[ $rc -eq 1 ]]; then
    echo "${out##*: }" # "<file>: Sig.Name FOUND" -> "Sig.Name FOUND"
    return 1
  fi
  [[ $rc -ge 2 ]] && return 2
  return 0
}

ms::yara_check() {
  local file="$1" hit
  [[ -z $YARA_RULES || ! -f $YARA_RULES ]] && return 0
  hit=$(yara -w -f "$YARA_RULES" "$file" 2> /dev/null | head -n1 | awk '{print $1}') || true
  [[ -n $hit ]] && {
    echo "$hit"
    return 1
  }
  return 0
}

ms::quarantine() {
  local file="$1" reason="$2"
  THREATS+=("${file}  ->  ${reason}")
  log::error "THREAT [${reason}]: ${file}"

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] would quarantine to ${QUARANTINE}"
    return 0
  fi

  local rel dest
  rel="${file#/}"
  dest="${QUARANTINE}/${rel}"
  mkdir -p "$(dirname "$dest")"
  mv -f -- "$file" "$dest" 2> /dev/null || {
    log::warn "  Could not move ${file} -- stripping exec bit in place as fallback."
    chmod a-x -- "$file" 2> /dev/null || true
    return 0
  }
  chmod a-x -- "$dest" 2> /dev/null || true
  printf '%s\t%s\t%s\n' "$(date -Is)" "$reason" "$file" >> "${QUARANTINE}/quarantine.log"
}

ms::scan_file() {
  local file="$1"
  [[ -f $file ]] || return 0
  [[ $file == "$QUARANTINE"/* ]] && return 0
  [[ $(basename -- "$file") =~ $SKIP_NAME_RE ]] && return 0

  SCANNED=$((SCANNED + 1))

  # 1. dangerous extension
  local ext="${file##*.}"
  ext="${ext,,}"
  if [[ $ext =~ $DANGEROUS_EXT_RE ]]; then
    ms::quarantine "$file" "dangerous-extension:.${ext}"
    return 0
  fi

  # 2. executable content masquerading as media
  local mime
  mime=$(file -b --mime-type -- "$file" 2> /dev/null || echo "")
  if [[ $mime =~ $EXEC_MIME_RE ]]; then
    ms::quarantine "$file" "executable-content:${mime}"
    return 0
  fi

  # 3. ClamAV (rc: 0 clean, 1 infected, 2 inconclusive)
  local sig rc=0
  sig=$(ms::clam_check "$file") || rc=$?
  if [[ $rc -eq 1 ]]; then
    ms::quarantine "$file" "clamav:${sig}"
    return 0
  fi

  # 4. YARA (optional)
  local yrule yrc=0
  yrule=$(ms::yara_check "$file") || yrc=$?
  if [[ $yrc -eq 1 ]]; then
    ms::quarantine "$file" "yara:${yrule}"
    return 0
  fi
}

# Build the file list for the current mode and scan it (NUL-safe).
ms::run() {
  local mode="$1"
  shift
  local -a finder=(find)

  case "$mode" in
    paths) finder+=("$@") ;;
    *) finder+=("${SCAN_PATHS[@]}") ;;
  esac

  # prune the quarantine dir, then select regular files
  finder+=(-path "$QUARANTINE" -prune -o -type f)
  if [[ $mode == incremental ]]; then
    local since
    since=$(cat "$STATE_FILE" 2> /dev/null || echo 0)
    finder+=(-newermt "@${since}")
  fi
  finder+=(-print0)

  local file
  while IFS= read -r -d '' file; do
    ms::scan_file "$file"
  done < <("${finder[@]}" 2> /dev/null)
}

ms::report() {
  local n="${#THREATS[@]}"
  log::info "Scanned ${SCANNED} file(s) with engine '${ENGINE:-none}'; ${n} threat(s) quarantined."
  ((n == 0)) && return 0
  local body
  body=$(printf '%s\n' "${THREATS[@]}")
  log::warn "Quarantined:"
  printf '  %s\n' "${THREATS[@]}" >&2
  [[ ${DRY_RUN:-0} -eq 1 ]] && return 0
  notification::pushover "Media scan: ${n} threat(s) on $(hostname)" "$body" 2> /dev/null || true
}

main() {
  banner::print "media scan"
  ((${#SCAN_PATHS[@]})) || log::fatal "No scan paths -- set DOTFILES_MEDIA_SCAN_PATHS or DOTFILES_HOMELAB_DATA_ROOT in local/env.sh"
  mkdir -p "$QUARANTINE" "$(dirname "$STATE_FILE")"
  ms::resolve_engine

  local start_ts sweep=0
  start_ts=$(date +%s)

  case "${1:-}" in
    --all)
      sweep=1
      ms::run all
      ;;
    --incremental | "")
      sweep=1
      if [[ ! -f $STATE_FILE ]]; then
        log::warn "No baseline yet -- establishing one now (skipping full scan)."
        log::warn "  Run 'media-scan.sh --all' once for an initial full sweep."
      else
        ms::run incremental
      fi
      ;;
    *)
      ms::run paths "$@"
      ;;
  esac

  # Advance the watermark only for sweep modes (explicit paths don't move it).
  if [[ $sweep -eq 1 && ${DRY_RUN:-0} -ne 1 ]]; then
    echo "$start_ts" > "$STATE_FILE"
  fi

  ms::report
}

main "$@"
