#!/usr/bin/env bash
# bin/doctor.sh -- machine-state health check for a provisioned profile.
#
# Audits what CI cannot see: symlink integrity, PATH, env completeness, installed
# vs pinned versions, secret-file permissions, and backup timers. Repo-health
# (shell syntax, markdown, secrets) is intentionally NOT duplicated here -- that is
# owned by shellcheck/bash -n, markdownlint, and gitleaks in pre-commit/CI.
set -Eeuo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DOTFILES_ROOT

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/bin/linker.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

trap 'log::warn "Interrupted. Exiting..."; exit 130' SIGINT

PROFILE_NAME="desktop"
FIX=0
EMIT_JSON=0

declare -A DOCTOR_RESULTS

# Single source of truth: ordered check names -> their functions. The summary,
# the JSON, and execution all read this, so they can never drift apart.
declare -a DOCTOR_CHECKS=(
  env symlinks path commands versions permissions env_paths orphans timers wallpaper
)
declare -A DOCTOR_FN=(
  [env]=doctor::check_env
  [symlinks]=doctor::check_symlinks
  [path]=doctor::check_path
  [commands]=doctor::check_commands
  [versions]=doctor::check_versions
  [permissions]=doctor::check_permissions
  [env_paths]=doctor::check_env_paths
  [orphans]=doctor::check_orphans
  [timers]=doctor::check_timers
  [wallpaper]=doctor::check_wallpaper
)

FMT_OK="[  OK  ]"
FMT_WARN="[ WARN ]"
FMT_FAIL="[ FAIL ]"

doctor::print_help() {
  cat << EOF
Usage: $(basename "$0") [options]

Machine-state health check: audits a provisioned profile for drift that CI can't
see. (Repo linting is handled by pre-commit/CI, not here.)

Options:
  -p, --profile <name>   Profile to check (default: desktop)
      --fix              Auto-repair broken symlinks
      --json             Emit machine-readable JSON summary
  -h, --help             Show this help

Checks:
  - env        local/env.sh completeness vs example
  - symlinks   symlink integrity per profile (--fix repairs)
  - path       PATH entries that don't exist on disk
  - commands   critical command dependencies
  - versions   installed vs pinned version per registry component (offline)
  - permissions secret files (restic_pass, ssh_config) are 0600
  - env_paths  DOTFILES_* path values in env.sh actually exist
  - orphans    core dotfiles in \$HOME pointing outside the repo
  - timers     restic backup user timers are enabled
  - wallpaper  wallpaper path resilience (stable symlink)
EOF
}

# -- check: environment completeness -----------------------------------------
doctor::check_env() {
  log::info "Verifying local/env.sh completeness..."
  local env_file="${DOTFILES_ROOT}/local/env.sh"
  local example_file="${DOTFILES_ROOT}/local/env.sh.example"

  if [[ ! -f $env_file ]]; then
    DOCTOR_RESULTS["env"]="fail"
    log::error "  (fail) local/env.sh is missing. Create it from local/env.sh.example."
    return 1
  fi

  local missing=() var
  while read -r var; do
    grep -q "^export $var=" "$env_file" || missing+=("$var")
  done < <(grep "^export DOTFILES_" "$example_file" | cut -d= -f1 | cut -d' ' -f2)

  if ((${#missing[@]} > 0)); then
    DOCTOR_RESULTS["env"]="warn"
    log::warn "  (warn) local/env.sh is missing variables defined in the example:"
    local m
    for m in "${missing[@]}"; do log::warn "      - $m"; done
    return 2
  fi

  log::info "  (ok) local/env.sh is complete"
  DOCTOR_RESULTS["env"]="ok"
}

# -- check: symlinks ---------------------------------------------------------
doctor::check_symlinks() {
  if [[ -z ${SYMLINKS+x} || ${#SYMLINKS[@]} -eq 0 ]]; then
    log::info "No SYMLINKS defined in profile -- skipping audit."
    DOCTOR_RESULTS["symlinks"]="ok"
    return 0
  fi

  log::info "Auditing symlinks for profile..."
  local conf drifted=0
  for conf in "${SYMLINKS[@]}"; do
    if linker::audit "$conf"; then
      log::info "  (ok) [$conf] healthy"
    else
      log::warn "  (warn) [$conf] drift detected"
      ((drifted++)) || :
    fi
  done

  if ((drifted == 0)); then
    DOCTOR_RESULTS["symlinks"]="ok"
    return 0
  fi

  if ((FIX)); then
    log::info "Repairing symlinks..."
    for conf in "${SYMLINKS[@]}"; do linker::apply "$conf" > /dev/null 2>&1; done
    local still_bad=0
    for conf in "${SYMLINKS[@]}"; do linker::audit "$conf" > /dev/null 2>&1 || ((still_bad++)) || :; done
    if ((still_bad == 0)); then
      log::info "  (ok) all symlinks auto-repaired"
      DOCTOR_RESULTS["symlinks"]="ok"
      return 0
    fi
  fi

  DOCTOR_RESULTS["symlinks"]="fail"
  log::error "  (fail) $drifted symlink set(s) drifted. Run with --fix to repair."
  return 1
}

# -- check: path sanity ------------------------------------------------------
doctor::check_path() {
  log::info "Checking PATH for non-existent directories..."
  local missing_dirs=0 dir
  local IFS=":"
  for dir in $PATH; do
    [[ -z $dir ]] && continue
    if [[ ! -d $dir ]]; then
      log::warn "  (warn) PATH entry missing: $dir"
      ((missing_dirs++)) || :
    fi
  done

  if ((missing_dirs == 0)); then
    log::info "  (ok) all PATH entries exist"
    DOCTOR_RESULTS["path"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["path"]="warn"
  log::warn "  (warn) $missing_dirs PATH entr(ies) do not exist on filesystem."
  return 2
}

# -- check: commands ---------------------------------------------------------
doctor::check_commands() {
  log::info "Checking critical commands..."
  local cmds=(bash git curl wget grep sed awk find ln readlink)
  local missing=() cmd
  for cmd in "${cmds[@]}"; do
    command::exists "$cmd" || missing+=("$cmd")
  done

  if ((${#missing[@]} == 0)); then
    log::info "  (ok) all critical commands installed"
    DOCTOR_RESULTS["commands"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["commands"]="fail"
  log::error "  (fail) missing core commands: ${missing[*]}"
  return 1
}

# -- check: version drift (installed vs pinned, offline) ---------------------
doctor::check_versions() {
  log::info "Checking installed vs pinned versions..."
  local components=(
    "${MEDIA_STACK_COMPONENTS[@]}"
    "${FONT_COMPONENTS[@]}"
    "${TOOL_COMPONENTS[@]}"
  )
  local drift=0 comp state installed pinned
  for comp in "${components[@]}"; do
    IFS='|' read -r state installed pinned <<< "$(status::compare "$comp")"
    case "$state" in
      outdated)
        log::warn "  (warn) ${comp,,}: ${installed} -> ${pinned}"
        ((drift++)) || :
        ;;
      missing)
        log::warn "  (warn) ${comp,,}: not installed (pinned ${pinned})"
        ((drift++)) || :
        ;;
    esac
  done

  if ((drift == 0)); then
    log::info "  (ok) all probed components match their pin"
    DOCTOR_RESULTS["versions"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["versions"]="warn"
  log::warn "  (warn) $drift component(s) drifted from the pinned version"
  return 2
}

# -- check: secret-file permissions ------------------------------------------
doctor::check_permissions() {
  log::info "Checking secret-file permissions..."
  local files=("${DOTFILES_ROOT}/local/restic_pass" "${DOTFILES_ROOT}/local/ssh_config")
  local bad=0 file mode
  for file in "${files[@]}"; do
    [[ -e $file ]] || continue
    mode=$(stat -c '%a' "$file" 2> /dev/null || echo "???")
    if [[ $mode != 600 ]]; then
      log::warn "  (warn) $(basename "$file") is $mode (expected 600): chmod 600 $file"
      ((bad++)) || :
    fi
  done

  if ((bad == 0)); then
    log::info "  (ok) secret files are 0600 (or absent)"
    DOCTOR_RESULTS["permissions"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["permissions"]="warn"
  return 2
}

# -- check: DOTFILES_* path validity -----------------------------------------
doctor::check_env_paths() {
  log::info "Verifying DOTFILES_* paths from env.sh exist..."
  # env.sh is already sourced by bash-utilities (bu::source_env); inspect the
  # live scalar DOTFILES_* values that look like filesystem paths.
  local bad=0 var value decl
  while read -r var; do
    [[ $var == DOTFILES_ROOT ]] && continue
    decl=$(declare -p "$var" 2> /dev/null || true)
    [[ $decl == "declare -a"* || $decl == "declare -A"* ]] && continue # skip arrays
    value="${!var:-}"
    [[ $value == /* || $value == "~"* ]] || continue # paths only
    value="${value/#\~/$HOME}"
    if [[ ! -e $value ]]; then
      log::warn "  (warn) $var -> $value (does not exist)"
      ((bad++)) || :
    fi
  done < <(compgen -v | grep '^DOTFILES_')

  if ((bad == 0)); then
    log::info "  (ok) all DOTFILES_* paths resolve"
    DOCTOR_RESULTS["env_paths"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["env_paths"]="warn"
  log::warn "  (warn) $bad DOTFILES_* path(s) set in env.sh do not exist."
  return 2
}

# -- check: orphan dotfiles --------------------------------------------------
doctor::check_orphans() {
  log::info "Checking for orphan symlinks in \$HOME and .config..."
  local orphans=() file target

  local scan_targets=(
    "$HOME/.bashrc"
    "$HOME/.profile"
    "$HOME/.bash_logout"
    "$HOME/.gitconfig"
    "$HOME/.ssh/config"
  )

  local scan_dirs=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    "${XDG_DATA_HOME:-$HOME/.local/share}/nemo/actions"
  )

  # Check specific high-value files
  for file in "${scan_targets[@]}"; do
    [[ -L $file ]] || continue
    target=$(readlink -f -- "$file" 2> /dev/null || true)
    if [[ -n $target && $target != "$DOTFILES_ROOT"/* ]]; then
      # Only flag if it looks like it WAS a dotfile (contains apps/ or scripts/)
      if [[ $target == *"/apps/"* || $target == *"/scripts/"* || $target == *"/config/"* ]]; then
        log::warn "  (warn) $file -> $target (points outside repo)"
        orphans+=("$file")
      fi
    fi
  done

  # Scan directories for any symlink pointing to an old repo location
  local dir
  for dir in "${scan_dirs[@]}"; do
    [[ -d $dir ]] || continue
    while read -r file; do
      target=$(readlink -f -- "$file" 2> /dev/null || true)
      if [[ -n $target && $target != "$DOTFILES_ROOT"/* ]]; then
        if [[ $target == *"/apps/"* || $target == *"/scripts/"* || $target == *"/config/"* ]]; then
          log::warn "  (warn) $file -> $target (points outside repo)"
          orphans+=("$file")
        fi
      fi
    done < <(find "$dir" -maxdepth 1 -type l)
  done

  if ((${#orphans[@]} == 0)); then
    log::info "  (ok) no stale dotfile symlinks detected"
    DOCTOR_RESULTS["orphans"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["orphans"]="warn"
  log::warn "  (warn) ${#orphans[@]} symlink(s) point to a different repository location."
  return 2
}

# -- check: restic backup timers ---------------------------------------------
doctor::check_timers() {
  log::info "Checking restic backup user timers..."
  if ! command::exists systemctl || ! systemctl --user show-environment &> /dev/null; then
    log::info "  (ok) no systemd user session -- skipping timer check"
    DOCTOR_RESULTS["timers"]="ok"
    return 0
  fi

  local timers=(restic-backup.timer restic-check.timer restic-test-restore.timer)
  local disabled=0 timer state
  for timer in "${timers[@]}"; do
    state=$(systemctl --user is-enabled "$timer" 2> /dev/null || true)
    if [[ $state != enabled ]]; then
      log::warn "  (warn) $timer is ${state:-not installed}"
      ((disabled++)) || :
    fi
  done

  if ((disabled == 0)); then
    log::info "  (ok) all restic timers enabled"
    DOCTOR_RESULTS["timers"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["timers"]="warn"
  return 2
}

# -- check: wallpaper integrity ----------------------------------------------
doctor::check_wallpaper() {
  log::info "Checking wallpaper configuration..."
  local wp_symlink="$HOME/.config/wallpaper-current"
  local fehbg="$HOME/.fehbg"
  local bad=0

  # 1. Check if the stable symlink exists and is valid
  if [[ -L $wp_symlink ]]; then
    local target
    target=$(readlink -f "$wp_symlink" || true)
    if [[ ! -f $target ]]; then
      log::warn "  (warn) wallpaper symlink is broken: $wp_symlink -> $target"
      ((bad++)) || :
    fi
  else
    log::info "  (info) stable wallpaper symlink not found (run wallpaper-set.sh to initialize)"
  fi

  # 2. Check .fehbg for stale repository paths
  if [[ -f $fehbg ]]; then
    if grep -q "$DOTFILES_ROOT" "$fehbg" && ! grep -q ".config/wallpaper-current" "$fehbg"; then
      log::warn "  (warn) .fehbg contains a direct repo path. It will break if the repo is renamed."
      log::warn "         Run 'wallpaper-set.sh <image>' to fix this with a stable path."
      ((bad++)) || :
    fi
  fi

  if ((bad == 0)); then
    log::info "  (ok) wallpaper configuration is resilient"
    DOCTOR_RESULTS["wallpaper"]="ok"
    return 0
  fi

  DOCTOR_RESULTS["wallpaper"]="warn"
  return 2
}

# -- orchestration -----------------------------------------------------------
doctor::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p | --profile)
        PROFILE_NAME="${2:?--profile requires an argument}"
        shift
        ;;
      --fix) FIX=1 ;;
      --json) EMIT_JSON=1 ;;
      -h | --help)
        doctor::print_help
        exit 0
        ;;
      *) log::fatal "Unknown option: $1" ;;
    esac
    shift
  done

  export FIX
  local profile_file="${DOTFILES_ROOT}/manifests/${PROFILE_NAME}.conf"
  [[ -f $profile_file ]] || log::fatal "profile not found: $profile_file"
  # shellcheck source=/dev/null
  source "$profile_file"
}

doctor::run_checks() {
  local name
  for name in "${DOCTOR_CHECKS[@]}"; do
    "${DOCTOR_FN[$name]}" || true
  done
}

doctor::overall_status() {
  local name
  for name in "${DOCTOR_CHECKS[@]}"; do
    [[ "${DOCTOR_RESULTS[$name]:-fail}" == "fail" ]] && {
      printf '1'
      return 0
    }
  done
  printf '0'
}

doctor::emit_json() {
  printf '{"profile":"%s","results":{' "$PROFILE_NAME"
  local name first=1
  for name in "${DOCTOR_CHECKS[@]}"; do
    ((first)) || printf ','
    first=0
    printf '"%s":"%s"' "$name" "${DOCTOR_RESULTS[$name]:-unknown}"
  done
  printf '},"exit":%s}\n' "$(doctor::overall_status)"
}

doctor::emit_summary() {
  echo ""
  log::info "-- summary -----------------------"
  local name status label
  for name in "${DOCTOR_CHECKS[@]}"; do
    status="${DOCTOR_RESULTS[$name]:-fail}"
    case "$status" in
      ok) label="${FG_GREEN}${FMT_OK}${RESET}" ;;
      warn) label="${FG_YELLOW}${FMT_WARN}${RESET}" ;;
      *) label="${FG_RED}${FMT_FAIL}${RESET}" ;;
    esac
    printf "%b  %s\n" "$label" "$name"
  done

  if [[ "$(doctor::overall_status)" == "0" ]]; then
    log::info "System is healthy."
  else
    log::error "System health check failed. Review errors above."
  fi
}

doctor::main() {
  doctor::parse_args "$@"
  ((EMIT_JSON)) || banner::print "doctor"
  ((EMIT_JSON)) || log::info "Starting health check for profile: $PROFILE_NAME"

  doctor::run_checks

  if ((EMIT_JSON)); then
    doctor::emit_json
  else
    doctor::emit_summary
  fi

  exit "$(doctor::overall_status)"
}

doctor::main "$@"
