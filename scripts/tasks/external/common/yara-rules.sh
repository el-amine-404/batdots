#!/usr/bin/env bash
# yara-rules -- fetch and compile the YARA ruleset used by pdf-sanitize's
# signature gate. Tracks the latest signature-base branch (YARA_RULES_* in
# config/versions.conf) and compiles a single .yarc into DOTFILES_YARA_RULES.
#
# Designed to be run often (pdf-sanitize triggers it lazily, ~once a day):
#   - Staleness-gated: does nothing if the ruleset is younger than
#     DOTFILES_YARA_MAX_AGE_HOURS (default 24). Force with --force / YARA_FORCE=1.
#   - Offline-safe: a failed fetch never fails the task -- it recompiles from the
#     cached clone, or keeps the existing ruleset, and exits 0 either way so
#     bootstrap never breaks when you are offline.
#   - Robust compile: each rule file is test-compiled alone (with the external
#     vars signature-base needs declared) so files needing an unavailable
#     module/syntax are skipped instead of failing the whole build.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

YR_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/yara"
YR_SRC="${YR_BASE}/src"
YR_OUT="${DOTFILES_YARA_RULES:?DOTFILES_YARA_RULES must be set in local/env.sh}"

# External variables signature-base (LOKI/THOR) rules reference; declared at
# compile time or those rules fail to compile. pdf::_yara_scan supplies the real
# per-file values at scan time.
YR_EXTERNALS=(-d filename="" -d filepath="" -d extension="" -d filetype="" -d owner="")

yr::is_fresh() {
  [[ -s $YR_OUT ]] || return 1
  local max_h="${DOTFILES_YARA_MAX_AGE_HOURS:?DOTFILES_YARA_MAX_AGE_HOURS must be set in local/env.sh}" age
  age=$(($(date +%s) - $(stat -c %Y "$YR_OUT")))
  ((age < max_h * 3600))
}

# Best-effort fetch of the latest rules (shallow). Returns 0 if the source tree
# is up to date, 1 if the network/git step failed (caller falls back to cache).
yr::sync() {
  local branch="${YARA_RULES_BRANCH:-master}"
  local url="https://github.com/${YARA_RULES_REPO}.git"
  local t="${DOTFILES_YARA_GIT_TIMEOUT:?DOTFILES_YARA_GIT_TIMEOUT must be set in local/env.sh}"

  if [[ -d "$YR_SRC/.git" ]]; then
    log::info "updating ${YARA_RULES_REPO} (${branch})..."
    timeout "$t" git -C "$YR_SRC" fetch --quiet --depth 1 origin "$branch" 2> /dev/null \
      && git -C "$YR_SRC" reset --quiet --hard FETCH_HEAD 2> /dev/null \
      && return 0
    return 1
  fi

  log::info "cloning ${YARA_RULES_REPO} (${branch})..."
  rm -rf "$YR_SRC"
  if timeout "$t" git clone --quiet --depth 1 --branch "$branch" "$url" "$YR_SRC" 2> /dev/null; then
    return 0
  fi
  rm -rf "$YR_SRC" # drop any partial clone
  return 1
}

# signature-base keeps rules under a top-level yara/ directory; scan that if
# present (avoids tests/ and vendor/), else fall back to every rule file.
yr::rules_root() {
  [[ -d "$YR_SRC/yara" ]] && printf '%s' "$YR_SRC/yara" || printf '%s' "$YR_SRC"
}

yr::has_rules() {
  local root
  root=$(yr::rules_root)
  [[ -d $root ]] && find "$root" -type f \( -iname '*.yar' -o -iname '*.yara' \) -print -quit 2> /dev/null | grep -q .
}

# Test-compile each file alone (yara 4.x cannot use the namespace:file syntax,
# and signature-base has no cross-file rule-id clashes, so plain paths are fine),
# then compile the survivors into one ruleset.
yr::compile() {
  local root good=0 skipped=0 f err
  local -a files=()
  root=$(yr::rules_root)
  while IFS= read -r -d '' f; do
    if yara -w "${YR_EXTERNALS[@]}" "$f" /dev/null > /dev/null 2>&1; then
      files+=("$f")
      good=$((good + 1))
    else
      skipped=$((skipped + 1))
    fi
  done < <(find "$root" -type f \( -iname '*.yar' -o -iname '*.yara' \) -print0)

  [[ $good -gt 0 ]] || {
    log::error "no YARA rule files compiled"
    return 1
  }

  dir::create "$(dirname -- "$YR_OUT")"
  if err=$(yarac "${YR_EXTERNALS[@]}" "${files[@]}" "$YR_OUT" 2>&1); then
    log::info "compiled ${good} rule file(s) -> ${YR_OUT} (${skipped} skipped as incompatible)"
  else
    log::error "yarac failed to build combined ruleset:"
    printf '%s\n' "$err" | head -10 | while IFS= read -r line; do log::error "  ${line}"; done
    return 1
  fi
}

main() {
  banner::print "yara-rules"

  command::exists git || {
    log::warn "git not installed -- cannot fetch YARA rules; skipping"
    exit 0
  }
  command::exists yara && command::exists yarac || {
    log::warn "yara/yarac not installed -- skipping rule compile (install the 'security' group)"
    exit 0
  }

  local forced=0
  [[ "${1:-}" == "--force" || "${1:-}" == "-f" || "${YARA_FORCE:-0}" == 1 ]] && forced=1

  if [[ $forced -eq 0 ]] && yr::is_fresh; then
    log::info "YARA ruleset is fresh (< ${DOTFILES_YARA_MAX_AGE_HOURS}h) -- skipping refresh"
    exit 0
  fi

  if ! yr::sync; then
    if yr::has_rules; then
      log::warn "could not reach ${YARA_RULES_REPO} (offline?) -- recompiling from cached clone"
    elif [[ -s $YR_OUT ]]; then
      log::warn "offline and no cached clone -- keeping the existing ruleset"
      exit 0
    else
      log::warn "offline and no cached rules -- YARA scan will be skipped until online"
      exit 0
    fi
  fi

  # Compile failures are non-fatal: keep any previous ruleset and never break
  # bootstrap over an optional defense-in-depth layer.
  if ! yr::compile; then
    [[ -s $YR_OUT ]] && log::warn "keeping previous ruleset after compile failure"
  fi
  exit 0
}

main "$@"
