#!/usr/bin/env bash
# pdfid -- Didier Stevens' structural PDF triage script, powering
# `pdf-sanitize --report`. It only parses PDF structure (never executes the
# document), so it is safe to run on untrusted files. Installed from a pinned,
# reviewed commit (see PDFID_* in config/versions.conf) as a python3 wrapper so
# it works regardless of whether a bare `python` exists.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

PDFID_SHARE="/usr/local/share/dotfiles/pdfid"
PDFID_SCRIPT="${PDFID_SHARE}/pdfid.py"
PDFID_STAMP="${PDFID_SHARE}/.version"
PDFID_BIN="/usr/local/bin/pdfid"

main() {
  banner::print "pdfid"
  os::check_dependency curl python3 || exit 1

  local version
  version=$(build::resolve_version "PDFID")

  if [[ -f $PDFID_STAMP && -x $PDFID_BIN ]] && [[ "$(cat "$PDFID_STAMP" 2> /dev/null)" == "$version" ]]; then
    log::info "pdfid ${version} already installed -- skipping"
    exit 0
  fi

  log::info "Installing pdfid (pinned ${version})..."
  $SUDO_CMD mkdir -p "$PDFID_SHARE"

  local tmp
  tmp=$(mktemp)
  if ! http::download "$PDFID_URL" "$tmp"; then
    log::error "pdfid: download failed from $PDFID_URL"
    rm -f "$tmp"
    exit 1
  fi
  $SUDO_CMD install -m 0644 "$tmp" "$PDFID_SCRIPT"
  rm -f "$tmp"

  $SUDO_CMD tee "$PDFID_BIN" > /dev/null << EOF
#!/bin/sh
exec python3 "${PDFID_SCRIPT}" "\$@"
EOF
  $SUDO_CMD chmod 0755 "$PDFID_BIN"
  printf '%s' "$version" | $SUDO_CMD tee "$PDFID_STAMP" > /dev/null

  build::verify_binary "pdfid"
  log::info "pdfid ${version} done"
}

main "$@"
