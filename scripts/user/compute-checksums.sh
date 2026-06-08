#!/usr/bin/env bash
# scripts/user/compute-checksums.sh -- Generate or verify SHA-256 checksum manifests.

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

CKS_DIR="."
CKS_CHECK=""

cks::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Recursively SHA-256-hashes every file under a directory into a timestamped
manifest, or verifies files against an existing manifest. Previous manifests
(checksums-*.sha256) and .git/ are excluded from generation.

Options:
  -d, --dir DIR       Directory to walk / write the manifest into (default: .)
  -c, --check FILE    Verify files against an existing manifest instead of
                      generating one. Prints only mismatched/missing files
                      plus a 'N of TOTAL failed' summary (quiet on success).
  -n, --dry-run       Show what would be hashed without writing a manifest
  -h, --help          Show this help message

Manifest name: checksums-YYYY-MM-DD__HHh-MMm-SSs.sha256
EOF
}

cks::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d | --dir)
        shift
        CKS_DIR="${1:?--dir requires a directory}"
        ;;
      -c | --check)
        shift
        CKS_CHECK="${1:?--check requires a manifest file}"
        ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        cks::usage
        exit 0
        ;;
      -*)
        log::error "Unknown option: $1"
        cks::usage >&2
        exit 1
        ;;
      *)
        log::error "Unexpected argument: $1"
        cks::usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

cks::require_tool() {
  command::exists sha256sum || log::fatal "sha256sum not found (GNU coreutils)"
}

cks::verify() {
  [[ -r $CKS_CHECK ]] || log::fatal "manifest not readable: $CKS_CHECK"

  local total
  total=$(wc -l < "$CKS_CHECK")
  log::info "Verifying $total file(s) against $(basename -- "$CKS_CHECK")"

  # --quiet prints a line only for files that FAIL, so a manifest with millions
  # of matching entries stays silent instead of scrolling 'OK' past the screen.
  # -c reads paths relative to the cwd, so verify from the manifest's directory.
  # sha256sum's own end-of-run warning goes to stderr; drop it for our summary.
  local failures rc=0
  failures=$(cd "$(dirname -- "$CKS_CHECK")" \
    && sha256sum --quiet --check "$(basename -- "$CKS_CHECK")" 2> /dev/null) || rc=$?

  if [[ $rc -eq 0 ]]; then
    log::info "All $total file(s) match the manifest - everything OK"
    return 0
  fi

  local count
  count=$(printf '%s' "$failures" | grep -c .)
  if [[ $count -eq 0 ]]; then
    log::fatal "verification failed (unreadable or malformed manifest)"
  fi

  # Each line is 'path: FAILED' (mismatch) or 'path: FAILED open or read' (gone).
  log::error "$count of $total file(s) FAILED:"
  printf '%s\n' "$failures" | sed 's/^/  /' >&2
  return 1
}

# Emit NUL-separated paths under current directory, skipping .git/ and prior manifests.
cks::find_files() {
  find . \
    \( -type d -name .git -o -type f -name 'checksums-*.sha256' \) -prune -o \
    -type f -print0
}

cks::generate() {
  [[ -d $CKS_DIR ]] || log::fatal "not a directory: $CKS_DIR"

  local target_dir
  target_dir=$(cd "$CKS_DIR" && pwd)

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] would hash the following files under $CKS_DIR:"
    (cd "$target_dir" && cks::find_files) | tr '\0' '\n'
    return 0
  fi

  local manifest_name="checksums-$(date +"%Y-%m-%d__%Hh-%Mm-%Ss").sha256"
  (
    cd "$target_dir"
    cks::find_files | xargs -0 --no-run-if-empty sha256sum > "$manifest_name"
  )
  log::info "Done - wrote $(wc -l < "$CKS_DIR/$manifest_name") checksum(s) to $CKS_DIR/$manifest_name"
}

main() {
  banner::print "checksums"
  cks::parse_args "$@"
  cks::require_tool
  if [[ -n $CKS_CHECK ]]; then
    cks::verify
  else
    cks::generate
  fi
}

main "$@"
