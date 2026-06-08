#!/usr/bin/env bash
set -Eeuo pipefail

GRUB_FILE="/etc/default/grub"
DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"
if [[ -f "${DOTFILES_ROOT}/lib/bash-utilities.sh" ]]; then
  # shellcheck source=/dev/null
  source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
else
  echo "Error: Critical library not found bash-utilities not found. make sure the ~/dotfiles folder exist" >&2
  exit 1
fi

if [[ -z ${PROFILE:-} ]]; then
  log::error "PROFILE env variable not defined"
  exit 1
fi

if [[ ${PROFILE:-} == "vm" ]]; then
  # systemd-detect-virt returns 0 if virtualized, non-zero if bare metal
  if ! systemd-detect-virt &> /dev/null; then
    log::warn "Profile is 'vm' but system detected as Bare Metal."
    log::warn "Skipping GRUB updates to prevent boot issues."
    exit 0
  fi
  log::info "Virtualization detected. Proceeding with VM configuration."
fi

CONFIG_FILE="${DOTFILES_ROOT}/config/grub/${PROFILE}.conf"
COMMON_CONFIG="${DOTFILES_ROOT}/config/grub/common.conf"

if [[ ! -f $CONFIG_FILE ]]; then
  log::warn "No GRUB configuration found for profile '$PROFILE' ($CONFIG_FILE). Skipping."
  exit 0
fi

# --- Helper Function: Set Key ---
grub::set_key() {
  local key="$1"
  local value="$2"
  local current_val

  current_val=$(grep -E "^#?${key}=" "$GRUB_FILE" | tail -n 1 | sed -E "s/^#?${key}=//; s/\"//g" | tr -d "'")

  if [[ $current_val == "$value" ]] && grep -q "^${key}=" "$GRUB_FILE"; then
    return 1 # No Change
  fi

  log::info "  Setting $key = $value"

  if grep -q "^#\?${key}=" "$GRUB_FILE"; then
    $SUDO_CMD sed -i "s|^#\?${key}=.*|${key}=\"${value}\"|" "$GRUB_FILE"
  else
    echo "${key}=\"${value}\"" | $SUDO_CMD tee -a "$GRUB_FILE" > /dev/null
  fi
  return 0 # Changed
}

grub::apply_config() {
  local config_file="$1"

  if [[ ! -f $config_file ]]; then
    return 0
  fi

  log::info "Loading config: $(basename "$config_file")"

  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ $key =~ ^#.*$ ]] || [[ -z $key ]] && continue

    # Remove quotes
    value="${value%\"}"
    value="${value#\"}"

    # Apply setting (Sets global flag if changed)
    if grub::set_key "$key" "$value"; then
      CHANGES_MADE=true
    fi
  done < "$config_file"
}

# --- Main Logic ---

log::info "Configuring GRUB for profile: $PROFILE"
CHANGES_MADE=false

# 1. Load Common Defaults (Always first)
COMMON_CONFIG="${DOTFILES_ROOT}/config/grub/common.conf"
grub::apply_config "$COMMON_CONFIG"

# 2. Load Profile Specifics (Overrides Common)
PROFILE_CONFIG="${DOTFILES_ROOT}/config/grub/${PROFILE}.conf"
if [[ -f $PROFILE_CONFIG ]]; then
  grub::apply_config "$PROFILE_CONFIG"
else
  log::warn "No specific configuration found for profile '$PROFILE'"
fi

# --- Finalize ---

if [[ $CHANGES_MADE == "true" ]]; then
  log::info "GRUB settings changed. Regenerating config..."

  # 1. Try standard wrapper (Debian/Ubuntu/Mint)
  if $SUDO_CMD update-grub; then
    log::info "GRUB updated (via update-grub)."

  # 2. Try standard grub-mkconfig (Arch/Gentoo)
  elif $SUDO_CMD grub-mkconfig -o /boot/grub/grub.cfg; then
    log::info "GRUB updated (via grub-mkconfig)."

  # 3. Try grub2-mkconfig (RedHat/Fedora/CentOS)
  elif command -v grub2-mkconfig &> /dev/null || $SUDO_CMD which grub2-mkconfig &> /dev/null; then
    if [[ -d "/boot/grub2" ]]; then
      $SUDO_CMD grub2-mkconfig -o /boot/grub2/grub.cfg
    else
      $SUDO_CMD grub2-mkconfig -o /boot/grub/grub.cfg
    fi
    log::info "GRUB updated (via grub2-mkconfig)."

  else
    log::error "Could not regenerate GRUB. 'update-grub' or 'grub-mkconfig' not found."
    log::error "Please run the update manually."
    exit 1
  fi

  log::info "Reboot required for changes to take effect."
else
  log::info "GRUB is already up to date."
fi
