#!/usr/bin/env bash
# Incremental malware scanner for the homelab media/download tree.
#
# Designed for TB-scale libraries: it scans only NEW files (since the last run)
# or the explicit paths it is handed -- it never re-scans the whole library.
#
# Per file it runs cheap, size-independent checks plus AV:
#   1. dangerous extension       (.exe/.scr/.js/.lnk/... hiding among media)
#   2. executable content        (a "movie.mp4" whose bytes are really a PE/ELF)
#   3. subtitle inspection       (.srt/.ass markup, oversize, binary payloads)
#   4. media decode sanity       (ffprobe: is the "video" really a video?)
#   5. ClamAV signatures         (clamdscan if the daemon is up, else clamscan)
#   6. VirusTotal reputation     (SHA-256 lookup only -- the file is never sent)
#   7. YARA rules                (optional, if DOTFILES_MEDIA_SCAN_YARA is set)
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

# VirusTotal: hash lookup only. The file itself is never uploaded, so nothing
# leaves the network but a fingerprint. Public API allows 500/day at 4/min.
VT_API_KEY="${DOTFILES_MEDIA_SCAN_VT_API_KEY:-}"
VT_THRESHOLD="${DOTFILES_MEDIA_SCAN_VT_THRESHOLD:-3}"
VT_MAX_LOOKUPS="${DOTFILES_MEDIA_SCAN_VT_MAX_LOOKUPS:-400}"
VT_SLEEP="${DOTFILES_MEDIA_SCAN_VT_SLEEP:-16}"

# Subtitles are untrusted input parsed by complex code (libass, ffmpeg) and are
# waved through by both the extension and MIME checks -- they need their own.
SUB_MAX_BYTES="${DOTFILES_MEDIA_SCAN_SUB_MAX_BYTES:-1048576}"

# A full episode or film that decodes to less than this is a decoy, not media.
MIN_DURATION_SEC="${DOTFILES_MEDIA_SCAN_MIN_DURATION:-180}"

# Extensions that have no business in a media tree.
DANGEROUS_EXT_RE='^(exe|scr|bat|cmd|com|pif|msi|js|jse|vbs|vbe|ps1|psm1|jar|lnk|sh|bin|run|app|dll|sys|reg|hta|wsf|cpl|gadget|sct)$'
# Content types that mean "this is a program", whatever the extension claims.
EXEC_MIME_RE='(x-dosexec|x-executable|x-pie-executable|x-elf|x-sharedlib|x-mach-binary|x-msdownload|portable-executable|x-shellscript|x-msdos-batch|x-ms-shortcut)'
# Incomplete-download artefacts to ignore.
SKIP_NAME_RE='\.(part|!qB|!ut|tmp|crdownload|partial)$'
# Subtitle containers, checked separately from binary media.
SUBTITLE_EXT_RE='^(srt|ass|ssa|sub|vtt|smi|ttml)$'
# Containers worth asking ffprobe to actually decode.
VIDEO_EXT_RE='^(mkv|mp4|avi|m4v|mov|ts|m2ts|webm)$'

ENGINE=""             # clamdscan | clamscan | "" (none)
declare -a THREATS=() # human-readable "path  ->  reason" lines
SCANNED=0
VT_USED=0      # lookups spent this run, capped by VT_MAX_LOOKUPS
INCONCLUSIVE=0 # files an engine could not actually read/scan

ms::resolve_engine() {
  if command -v clamdscan > /dev/null 2>&1 \
    && systemctl is-active --quiet clamav-daemon 2> /dev/null; then
    ENGINE="clamdscan"
  elif command -v clamscan > /dev/null 2>&1; then
    ENGINE="clamscan"
  else
    log::warn "ClamAV not available -- signature scanning is DISABLED."
    log::warn "  Install it with the 'clamav' system task, or scans run degraded."
    DEGRADED=1
  fi
}

# Echo the ClamAV signature name if infected; return 1 if infected, 0 if clean,
# 2 on scanner error (treated as inconclusive, not a block).
ms::clam_check() {
  local file="$1" out rc
  [[ -z $ENGINE ]] && return 0
  out=$("$ENGINE" --no-summary --infected --scan-archive=yes -- "$file" 2> /dev/null) && rc=0 || rc=$?
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

# Subtitles are text, so the MIME check passes them and ClamAV has almost no
# signatures for them -- yet they are parsed by libass/ffmpeg, server-side, when
# Jellyfin burns them into a transcode. Check them on their own terms.
ms::subtitle_check() {
  local file="$1" ext size
  ext="${file##*.}"
  ext="${ext,,}"
  [[ $ext =~ $SUBTITLE_EXT_RE ]] || return 0

  size=$(stat -c%s -- "$file" 2> /dev/null || echo 0)
  if ((size > SUB_MAX_BYTES)); then
    echo "oversized:${size}b"
    return 1
  fi

  if grep -qiE '<script|javascript:|<iframe|<object|<embed|data:text/html' -- "$file" 2> /dev/null; then
    echo "embedded-markup"
    return 1
  fi

  if [[ $ext =~ ^(ass|ssa)$ ]] \
    && grep -qiE '^[[:space:]]*(Filename|Import|Include)[[:space:]]*:' -- "$file" 2> /dev/null; then
    echo "ass-external-ref"
    return 1
  fi

  # control bytes have no business in a subtitle file
  if grep -qP '[\x00-\x08\x0e-\x1f]' -- "$file" 2> /dev/null; then
    echo "binary-in-text"
    return 1
  fi
  return 0
}

# Fake media: not malware, just not the thing it claims to be. The *arr apps
# bound file size but never confirm the bytes decode as video of sane length.
ms::media_sanity() {
  local file="$1" ext dur vstreams
  ext="${file##*.}"
  ext="${ext,,}"
  [[ $ext =~ $VIDEO_EXT_RE ]] || return 0
  command -v ffprobe > /dev/null 2>&1 || return 0

  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 -- "$file" 2> /dev/null || echo "")
  if [[ -z $dur || $dur == "N/A" ]]; then
    echo "undecodable"
    return 1
  fi

  vstreams=$(ffprobe -v error -select_streams v -show_entries stream=index \
    -of csv=p=0 -- "$file" 2> /dev/null | grep -c . || true)
  if [[ ${vstreams:-0} -eq 0 ]]; then
    echo "no-video-stream"
    return 1
  fi

  if ((${dur%%.*} < MIN_DURATION_SEC)); then
    echo "suspiciously-short:${dur%%.*}s"
    return 1
  fi
  return 0
}

# VirusTotal by SHA-256 lookup. Only the hash is sent -- uploading the file
# would share it with VT partners, which a private library cannot accept.
# A 404 means nobody has ever submitted this file: unknown, NOT clean.
ms::vt_check() {
  local file="$1" sha body malicious http
  [[ -z $VT_API_KEY ]] && return 0
  ((VT_USED >= VT_MAX_LOOKUPS)) && return 0
  command -v curl > /dev/null 2>&1 || return 0
  command -v jq > /dev/null 2>&1 || return 0

  sha=$(sha256sum -- "$file" 2> /dev/null | cut -d\  -f1)
  [[ -z $sha ]] && return 0

  ((VT_USED > 0)) && sleep "$VT_SLEEP"
  VT_USED=$((VT_USED + 1))

  body=$(curl -sS --max-time 25 -w '\n%{http_code}' \
    -H "x-apikey: ${VT_API_KEY}" \
    "https://www.virustotal.com/api/v3/files/${sha}" 2> /dev/null) || return 2
  http="${body##*$'\n'}"
  body="${body%$'\n'*}"

  # 404 unknown, 429 rate-limited, 401 bad key -- none are verdicts
  [[ $http == "404" ]] && return 0
  if [[ $http != "200" ]]; then
    log::warn "  VirusTotal returned HTTP ${http} -- treating as inconclusive."
    return 2
  fi

  malicious=$(jq -r '.data.attributes.last_analysis_stats.malicious // empty' <<< "$body")
  [[ -z $malicious ]] && return 0
  if ((malicious >= VT_THRESHOLD)); then
    echo "vt:${malicious}-engines"
    return 1
  fi
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

  # 3. subtitle-specific inspection (cheap, text-only)
  local subhit subrc=0
  subhit=$(ms::subtitle_check "$file") || subrc=$?
  if [[ $subrc -eq 1 ]]; then
    ms::quarantine "$file" "subtitle:${subhit}"
    return 0
  fi

  # 4. does the "video" actually decode as video?
  local medhit medrc=0
  medhit=$(ms::media_sanity "$file") || medrc=$?
  if [[ $medrc -eq 1 ]]; then
    ms::quarantine "$file" "fake-media:${medhit}"
    return 0
  fi

  # 5. ClamAV (rc: 0 clean, 1 infected, 2 inconclusive)
  local sig rc=0
  sig=$(ms::clam_check "$file") || rc=$?
  if [[ $rc -eq 1 ]]; then
    ms::quarantine "$file" "clamav:${sig}"
    return 0
  elif [[ $rc -ge 2 ]]; then
    # unreadable by the daemon, corrupt, or over a scanner limit -- NOT clean
    INCONCLUSIVE=$((INCONCLUSIVE + 1))
    [[ ${VERBOSE:-0} -eq 1 ]] && log::warn "  inconclusive scan: ${file}"
  fi

  # 6. VirusTotal reputation (hash only; rc 2 = inconclusive, never a block)
  local vthit vtrc=0
  vthit=$(ms::vt_check "$file") || vtrc=$?
  if [[ $vtrc -eq 1 ]]; then
    ms::quarantine "$file" "virustotal:${vthit}"
    return 0
  elif [[ $vtrc -ge 2 ]]; then
    INCONCLUSIVE=$((INCONCLUSIVE + 1))
  fi

  # 7. YARA (optional)
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

ms::notify() {
  local title="$1" body="$2"
  local hook="${DOTFILES_DISCORD_WEBHOOK:-${DISCORD_WEBHOOK:-}}"
  if [[ -n $hook ]]; then
    notification::discord "$title" "$body" "$hook" 2> /dev/null && return 0
  fi
  notification::pushover "$title" "$body" 2> /dev/null || true
}

ms::report() {
  local n="${#THREATS[@]}" host
  host=$(hostname)
  log::info "Scanned ${SCANNED} file(s) with engine '${ENGINE:-none}'; ${n} threat(s) quarantined."
  ((VT_USED > 0)) && log::info "  VirusTotal lookups used: ${VT_USED}/${VT_MAX_LOOKUPS}"

  # An engine that cannot read the files reports every one of them as clean.
  # Surface that rather than let a broken scan look like a successful one.
  if ((INCONCLUSIVE > 0)); then
    log::warn "  ${INCONCLUSIVE}/${SCANNED} file(s) could not be conclusively scanned."
    if ((SCANNED > 0 && INCONCLUSIVE * 2 > SCANNED)) && [[ ${DRY_RUN:-0} -ne 1 ]]; then
      ms::notify "Media scan UNRELIABLE on ${host}" \
        "${INCONCLUSIVE} of ${SCANNED} files could not be scanned (check ClamAV permissions on the media tree)."
    fi
  fi

  # a degraded scan reporting success is worse than a scan that fails loudly
  if [[ ${DEGRADED:-0} -eq 1 && ${DRY_RUN:-0} -ne 1 ]]; then
    ms::notify "Media scan DEGRADED on ${host}" \
      "ClamAV is not installed -- signature scanning was skipped."
  fi

  ((n == 0)) && return 0
  local body
  body=$(printf '%s\n' "${THREATS[@]}")
  log::warn "Quarantined:"
  printf '  %s\n' "${THREATS[@]}" >&2
  [[ ${DRY_RUN:-0} -eq 1 ]] && return 0
  ms::notify "Media scan: ${n} threat(s) on ${host}" "$body"
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
