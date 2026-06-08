#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

# Every *.service / *.timer here is installed + enabled for the current user.
# Add a unit = drop a file in this dir; this task auto-discovers and enables it.
USVC_SRC_DIR="${DOTFILES_ROOT}/apps/systemd/user"
USVC_DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# A .service that has a sibling .timer is started BY the timer, not at boot. It
# must be linked (loadable) but never enabled -- and the timer refuses to start
# unless this service is already loaded.
usvc::is_timer_driven() {
  local unit="$1"
  [[ $unit == *.service && -f "${USVC_SRC_DIR}/${unit%.service}.timer" ]]
}

usvc::units() {
  [[ -d $USVC_SRC_DIR ]] || return 0
  local f
  for f in "$USVC_SRC_DIR"/*.service "$USVC_SRC_DIR"/*.timer; do
    [[ -f $f ]] && basename -- "$f"
  done
}

# During provisioning (e.g. over SSH) there may be no per-user systemd instance
# to talk to -- detect that so we can degrade to a hint instead of failing.
usvc::session_available() {
  command -v systemctl > /dev/null 2>&1 || return 1
  systemctl --user show-environment > /dev/null 2>&1
}

usvc::print_manual_hint() {
  log::warn "No user systemd session available -- enable later from your desktop with:"
  local unit
  for unit in "$@"; do
    log::warn "  systemctl --user enable --now ${USVC_SRC_DIR}/${unit}"
  done
}

# Global to track if we need a manager reload
USVC_NEEDS_RELOAD=0

# Link a timer-driven service so the manager can load it, without enabling it.
usvc::link_unit() {
  local unit="$1"
  local dest="${USVC_DEST_DIR}/${unit}"
  local src="${USVC_SRC_DIR}/${unit}"

  if [[ -L "$dest" ]]; then
    local target
    target=$(readlink -f "$dest" || true)
    if [[ "$target" == "$(readlink -f "$src")" ]]; then
      log::debug "${unit} already linked correctly."
      return 0
    fi
    log::info "Removing stale/incorrect link for ${unit}..."
    [[ ${DRY_RUN:-0} == 1 ]] || rm -f "$dest"
    USVC_NEEDS_RELOAD=1
  fi

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would link ${unit} (timer-activated; loadable, not enabled)"
    return 0
  fi
  log::info "Linking timer-activated ${unit}..."
  systemctl --user link "$src" > /dev/null 2>&1 \
    || log::warn "Could not link ${unit}."
  USVC_NEEDS_RELOAD=1
}

usvc::enable_unit() {
  local unit="$1"
  local src="${USVC_SRC_DIR}/${unit}"

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    systemctl --user is-enabled "$unit" > /dev/null 2>&1 \
      && log::debug "${unit} already enabled." \
      || log::info "[dry-run] would enable ${unit}"
    return 0
  fi

  # If already enabled, check if it's pointing to the right place.
  # Using --force handles the symlink update if it already exists.
  log::info "Enabling ${unit}..."
  systemctl --user enable --force "$src" > /dev/null 2>&1 \
    || {
      log::warn "Could not enable ${unit} (missing [Install] section, or needs a live session)."
      return 0
    }

  # Ensure it's actually running -- a prior run may have enabled but failed to start.
  # We ignore failures here as some units (like services without RemainAfterExit=yes)
  # might have finished running already.
  systemctl --user is-active "$unit" > /dev/null 2>&1 \
    || systemctl --user start "$unit" > /dev/null 2>&1 \
    || log::debug "Could not start ${unit} (this is normal for some services)."
}

main() {
  banner::print "user services"

  local units=()
  mapfile -t units < <(usvc::units)
  ((${#units[@]})) || {
    log::info "No user units in apps/systemd/user -- nothing to do."
    return 0
  }

  if ! usvc::session_available; then
    usvc::print_manual_hint "${units[@]}"
    return 0
  fi

  # Phase 1: link timer-driven services so they're loadable before their timers
  # start (else: "Refusing to start, unit X.service to trigger not loaded").
  local unit
  for unit in "${units[@]}"; do
    usvc::is_timer_driven "$unit" && usvc::link_unit "$unit"
  done

  # If we changed links, we MUST reload before Phase 2 or systemctl enable fails
  # with "unit not found" or "missing section" errors because it has the old path.
  if [[ $USVC_NEEDS_RELOAD == 1 && ${DRY_RUN:-0} == 0 ]]; then
    log::info "Reloading systemd manager..."
    systemctl --user daemon-reload
  fi

  # Phase 2: enable (+start) timers and standalone services; timer-driven
  # services are pulled in by their timer, so they're not enabled here.
  for unit in "${units[@]}"; do
    usvc::is_timer_driven "$unit" && continue
    usvc::enable_unit "$unit"
  done
  log::info "User services up to date."
}

main "$@"
