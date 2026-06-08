#!/usr/bin/env bash
# restic -- backup engine. Installs the official prebuilt binary from the pinned
# GitHub release (SHA256-verified against the release's SHA256SUMS), to
# /usr/local/bin where it shadows -- then purges -- the years-old Debian apt build.
# Architecture is auto-detected. Re-running this is how you update restic: bump
# RESTIC_VERSION (update-versions.yml does this automatically) and run again.
set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"

# build::binary_already_installed runs this via `bash -c`, so it must be a
# self-contained command string (no shell functions) -- prints the X.Y.Z it finds.
RESTIC_VERSION_PROBE="restic version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1"

# Map uname arch -> restic's asset naming (linux_amd64 / linux_arm64).
restic::asset_arch() {
  case "$(os::get_architecture)" in
    x86_64) printf 'amd64' ;;
    aarch64) printf 'arm64' ;;
    *) return 1 ;;
  esac
}

# Verify the downloaded archive against the SHA256SUMS file from the same release.
restic::verify_sha256() {
  local archive="$1" sums="$2" asset="$3" expected actual
  expected=$(awk -v a="$asset" '$2 == a {print $1}' "$sums")
  [[ -n $expected ]] || {
    log::error "restic: ${asset} not listed in SHA256SUMS"
    return 1
  }
  actual=$(sha256sum "$archive" | awk '{print $1}')
  [[ $actual == "$expected" ]] || {
    log::error "restic: SHA256 mismatch (expected ${expected}, got ${actual})"
    return 1
  }
  log::info "restic: SHA256 verified"
}

main() {
  banner::print "restic"
  os::check_dependency curl bzip2 sha256sum awk || exit 1

  local version asset_arch
  version=$(build::resolve_version "RESTIC")
  build::binary_already_installed "restic" "$version" "$RESTIC_VERSION_PROBE" && exit 0

  asset_arch=$(restic::asset_arch) || {
    log::error "restic: unsupported architecture: $(os::get_architecture)"
    exit 1
  }

  local base="https://github.com/${RESTIC_REPO}/releases/download/${RESTIC_TAG_PREFIX}${version}"
  local asset="restic_${version}_linux_${asset_arch}.bz2"

  local tmp sums
  tmp=$(mktemp)
  sums=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '${tmp}' '${sums}'" EXIT

  log::info "Installing restic ${version} (linux_${asset_arch})..."
  http::download "${base}/${asset}" "$tmp" || {
    log::error "restic: download failed: ${base}/${asset}"
    exit 1
  }
  http::download "${base}/SHA256SUMS" "$sums" || {
    log::error "restic: could not fetch SHA256SUMS"
    exit 1
  }
  restic::verify_sha256 "$tmp" "$sums" "$asset" || exit 1

  bunzip2 -c "$tmp" | $SUDO_CMD tee /usr/local/bin/restic > /dev/null
  $SUDO_CMD chmod +x /usr/local/bin/restic

  # Drop the apt build now that the official one owns /usr/local/bin (earlier in PATH).
  dpkg -s restic > /dev/null 2>&1 && build::purge_system_package restic

  hash -r 2> /dev/null || true
  build::verify_binary "restic"
  log::info "restic ${version} done"
}

main "$@"
