#!/usr/bin/env bash
# Helpers for adding APT repositories and GPG keys safely.
# Used by scripts that bring in third-party debian sources.

installer::ensure_deps() {
  local missing=()
  command -v curl &> /dev/null || missing+=(curl)
  command -v gpg &> /dev/null || missing+=(gnupg)
  [[ -e /etc/ssl/certs/ca-certificates.crt ]] || missing+=(ca-certificates)
  [[ ${#missing[@]} -eq 0 ]] && return 0

  log::info "Installing prerequisites: ${missing[*]}"
  installer::ensure_sudo
  $SUDO_CMD apt-get update -y > /dev/null
  $SUDO_CMD apt-get install -y "${missing[@]}" > /dev/null
}

installer::ensure_sudo() {
  if [[ -z ${SUDO_CMD-} && $EUID -ne 0 ]]; then
    log::fatal "Root privileges required."
  fi
}

installer::download_file() {
  local url="$1" dest="$2"
  command -v curl &> /dev/null || installer::ensure_deps
  http::download "$url" "$dest"
}

installer::apt::add_key() {
  local name="$1" url="$2"
  local keyring="/etc/apt/keyrings/${name}.gpg"

  installer::ensure_sudo
  installer::ensure_deps
  $SUDO_CMD mkdir -p -m 0755 /etc/apt/keyrings

  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' RETURN

  log::info "Fetching key: $name"
  if ! curl -fsSL "$url" -o "$tmp"; then
    log::error "Could not download key: $url"
    return 1
  fi

  if grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$tmp"; then
    log::debug "ASCII key -- dearmoring"
    $SUDO_CMD gpg --dearmor --yes -o "$keyring" < "$tmp"
  else
    log::debug "Binary key -- installing as-is"
    $SUDO_CMD cp "$tmp" "$keyring"
  fi
  $SUDO_CMD chmod 644 "$keyring"
  log::info "Key installed: $keyring"
}

installer::apt::add_repo() {
  local name="$1" repo_string="$2"
  local target="/etc/apt/sources.list.d/${name}.list"

  installer::ensure_sudo

  local repo_url
  repo_url=$(echo "$repo_string" | grep -oE 'https?://[^ ]+')
  if [[ -n $repo_url ]]; then
    local conflicts
    conflicts=$(grep -rl "$repo_url" /etc/apt/sources.list.d/ 2> /dev/null || true)
    while IFS= read -r f; do
      [[ -z $f || $f == "$target" ]] && continue
      log::warn "Removing conflicting repo file: $f"
      $SUDO_CMD rm -f "$f"
    done <<< "$conflicts"
  fi

  log::info "Configuring repo: $name"
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$repo_string" > "$tmp"
  $SUDO_CMD mv "$tmp" "$target"
  $SUDO_CMD chmod 644 "$target"
  $SUDO_CMD apt-get update -qq
}

installer::apt::install() {
  installer::ensure_sudo
  log::info "APT install: $*"
  $SUDO_CMD DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}
