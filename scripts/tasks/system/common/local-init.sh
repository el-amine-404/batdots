#!/usr/bin/env bash
# scripts/tasks/system/common/local-init.sh
# Idempotently initializes personal configuration and stops for user review.
set -Eeuo pipefail
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

log::info "  Validating local configuration..."

initialized=false
for example in "${DOTFILES_ROOT}/local"/*.example; do
  [[ -f "$example" ]] || continue

  target="${example%.example}"
  if [[ ! -f "$target" ]]; then
    if [[ ${DRY_RUN:-0} == 1 ]]; then
      log::info "    [dry-run] would initialize $(basename "$target")"
    else
      cp "$example" "$target"
      log::warn "    Created $(basename "$target") from template"
      initialized=true
    fi
  fi
done

if [[ $initialized == true ]]; then
  log::error "New local configuration files were created in 'local/'."
  log::fatal "Please review and edit them (especially 'env.sh') before re-running."
fi
