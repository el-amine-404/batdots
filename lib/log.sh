#!/usr/bin/env bash
# Leveled logger that writes to stderr (colored) and an optional logfile.

LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FATAL_TRACE="${LOG_FATAL_TRACE:-1}"

log::_level_num() {
  case "$1" in
    DEBUG) echo 10 ;;
    INFO) echo 20 ;;
    WARN) echo 30 ;;
    ERROR) echo 40 ;;
    FATAL) echo 50 ;;
    *) echo 20 ;;
  esac
}

log::_color() {
  case "$1" in
    DEBUG) echo "$FG_BLUE" ;;
    INFO) echo "$FG_GREEN" ;;
    WARN) echo "$FG_YELLOW" ;;
    ERROR | FATAL) echo "$FG_RED" ;;
    *) echo "$RESET" ;;
  esac
}

log::_logfile() {
  [[ -z "${LOG_DIR:-}" ]] && return 0
  local tag="${LOG_TAG:-$(basename -- "${0:-shell}")}"
  [[ -d $LOG_DIR ]] || mkdir -p -- "$LOG_DIR" 2> /dev/null || return 0
  printf '%s' "${LOG_DIR}/${tag}.log"
}

log::_caller() {
  local i fn src line
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    fn="${FUNCNAME[$i]}"
    case "$fn" in log::*) continue ;; esac
    src="${BASH_SOURCE[$i]:-?}"
    line="${BASH_LINENO[$((i - 1))]:-0}"
    printf '%s:%s %s' "${src##*/}" "$line" "$fn"
    return
  done
  printf 'shell:0 main'
}

log::stacktrace() {
  echo "Stacktrace:" >&2
  local depth=0 i
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    case "${FUNCNAME[$i]}" in log::*) continue ;; esac
    printf '  #%d %s at %s:%s\n' \
      "$depth" "${FUNCNAME[$i]}" "${BASH_SOURCE[$i]##*/}" "${BASH_LINENO[$((i - 1))]:-0}" >&2
    ((depth++))
  done
}

log::log() {
  local level="$1"
  shift
  local msg="$*"
  [[ "$(log::_level_num "$level")" -ge "$(log::_level_num "$LOG_LEVEL")" ]] || return 0

  local ts caller line file
  # Use milliseconds if date supports it (standard on Linux)
  if [[ $(date +%N) != "N" ]]; then
    ts="$(date +'%Y-%m-%d %H:%M:%S.%3N')"
  else
    ts="$(date +'%Y-%m-%d %H:%M:%S')"
  fi

  caller="$(log::_caller)"
  line="${ts} [${level}] [${LOG_TAG:-$(basename -- "${0:-shell}")}] [${caller}] : ${msg}"

  # Clear current line if TTY to prevent mess with progress bars (\r + \033[K)
  if [[ -t 2 ]]; then
    printf "\r\033[K%s%s%s\n" "$(log::_color "$level")" "$line" "$RESET" >&2
  else
    printf "%s%s%s\n" "$(log::_color "$level")" "$line" "$RESET" >&2
  fi

  file="$(log::_logfile)"
  if [[ -n $file ]]; then
    printf '%s\n' "$line" >> "$file"
  fi

  if [[ $level == "FATAL" && $LOG_FATAL_TRACE == "1" ]]; then
    log::stacktrace
  fi
  return 0
}

log::debug() { log::log DEBUG "$@"; }
log::info() { log::log INFO "$@"; }
log::warn() { log::log WARN "$@"; }
log::error() { log::log ERROR "$@"; }
log::fatal() {
  log::log FATAL "$@"
  exit 1
}
