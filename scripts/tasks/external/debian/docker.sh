#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

if ! type -t installer::apt::add_key > /dev/null; then
  echo "ERROR: Function installer::apt::add_key not defined. Check lib/installers.sh"
  exit 1
fi

if [[ -f /etc/os-release ]]; then
  source /etc/os-release
else
  log::fatal "Cannot detect OS: /etc/os-release missing."
fi

clean_old_versions() {
  log::info "Step 1/4: Cleaning old Docker versions..."

  local pkgs=(
    "docker.io" "docker-doc" "docker-compose" "docker-compose-v2"
    "podman-docker" "containerd" "runc" "docker-ce" "docker-ce-cli"
    "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"
    "docker-ce-rootless-extras"
  )

  # Loop efficiently
  for pkg in "${pkgs[@]}"; do
    $SUDO_CMD apt-get -yq remove "$pkg" > /dev/null || true
    $SUDO_CMD apt-get -yq purge "$pkg" > /dev/null || true
  done

  log::info "Removing residual config and data files..."
  # delete all images, containers, and volumes (for a clean install)
  # (if you care about your images you must host them to docker hub)
  $SUDO_CMD rm -rf /var/lib/docker /var/lib/containerd
  # remove: source list, keyrings
  $SUDO_CMD rm -f /etc/apt/sources.list.d/docker.list \
    /etc/apt/sources.list.d/docker.sources \
    /etc/apt/keyrings/docker.asc \
    /etc/apt/keyrings/docker.gpg

  # remove daemon configs
  $SUDO_CMD rm -f /etc/docker/daemon.json            # regular setup
  $SUDO_CMD rm -f "$HOME/.config/docker/daemon.json" # rootless mode

  # You have to delete any edited configuration files manually.
  # rm -r $HOME/.docker
}

# 3. Function: Setup Repository (The Smart Logic)
# ------------------------------------------------------------------------------
setup_repository() {
  log::info "Step 2/4: Setting up Docker Repository..."

  local suite
  local os_type

  # Distro Detection Logic (Preserved from your old script)
  case "${ID,,}" in
    linuxmint | ubuntu | pop | neon)
      os_type="ubuntu"
      suite="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
      ;;
    debian)
      os_type="debian"
      suite="${VERSION_CODENAME}"
      ;;
    *)
      log::error "Unsupported distribution for this Docker script: $ID"
      return 1
      ;;
  esac

  if [[ -z $suite ]]; then
    log::fatal "Could not detect distribution codename (suite)."
  fi

  log::info "Detected: $ID ($os_type) -> Suite: $suite"

  # A. Add Key (Using Helper)
  installer::apt::add_key "docker" "https://download.docker.com/linux/${os_type}/gpg"

  # B. Add Repo (Using Helper)
  local arch
  arch=$(dpkg --print-architecture)
  local repo_string="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${os_type} ${suite} stable"

  installer::apt::add_repo "docker" "$repo_string"
}

# 4. Function: Install Packages
# ------------------------------------------------------------------------------
install_packages() {
  log::info "Step 3/4: Installing Docker Packages..."

  # Install dependencies first
  $SUDO_CMD DEBIAN_FRONTEND=noninteractive apt-get install -yq ca-certificates curl

  # Install Docker
  $SUDO_CMD DEBIAN_FRONTEND=noninteractive apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Verification
  if ! command -v docker &> /dev/null; then
    log::error "Docker installation failed."
    return 1
  fi

  docker --version || true
  docker compose version || true
}

# 5. Function: Post-Install Configuration
# ------------------------------------------------------------------------------
configure_system() {
  # allow non-privileged users to run Docker commands
  log::info "Step 4/4: Post-Installation Configuration..."

  if ! getent group docker > /dev/null; then
    $SUDO_CMD groupadd docker
  fi

  $SUDO_CMD usermod -aG docker "$USER"
  log::info "User '$USER' added to 'docker' group."
  # activate the changes to groups OR Log out and log back in so that your group membership is re-evaluated.
  # newgrp docker
  echo "Log out and log back in so your 'docker' group membership takes effect"

  ## Configure Docker to start on boot with systemd
  log::info "Enabling Systemd services..."
  $SUDO_CMD systemctl enable --now docker.service
  $SUDO_CMD systemctl enable --now containerd.service
}

# ==============================================================================
# EXECUTION FLOW
# ==============================================================================

clean_old_versions
setup_repository
install_packages
configure_system

log::info "Docker Engine installed successfully."
log::warn "You must log out and log back in for group changes to take effect."
