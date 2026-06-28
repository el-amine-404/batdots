#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../../../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"

DATA_ROOT="${DOTFILES_HOMELAB_DATA_ROOT:?DOTFILES_HOMELAB_DATA_ROOT must be set in local/env.sh}"
CONFIGS_ROOT="${DOTFILES_HOMELAB_CONFIGS_ROOT:?DOTFILES_HOMELAB_CONFIGS_ROOT must be set in local/env.sh}"
VOLUMES_ROOT="${DOTFILES_HOMELAB_VOLUMES_ROOT:?DOTFILES_HOMELAB_VOLUMES_ROOT must be set in local/env.sh}"
SITES_ROOT="${DOTFILES_HOMELAB_SITES_ROOT:?DOTFILES_HOMELAB_SITES_ROOT must be set in local/env.sh}"

hldirs::create_infrastructure() {
  log::info "Creating infrastructure directories..."

  local dirs=(
    "$CONFIGS_ROOT"
    "$VOLUMES_ROOT"
    "$SITES_ROOT"
    "$DATA_ROOT"
  )

  local d
  for d in "${dirs[@]}"; do
    if [[ ! -d $d ]]; then
      if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        log::info "  [DRY RUN] Would create directory $d"
      else
        $SUDO_CMD mkdir -p "$d"
      fi
    fi
  done
}

hldirs::create_media_structure() {
  log::info "Creating media library structures..."

  local subdirs=(
    "torrents/books" "torrents/movies" "torrents/music" "torrents/tv"
    "usenet/incomplete"
    "usenet/complete/books" "usenet/complete/movies" "usenet/complete/music" "usenet/complete/tv"
    "media/books" "media/movies" "media/music" "media/tv"
  )

  local sub
  for sub in "${subdirs[@]}"; do
    local d="${DATA_ROOT}/${sub}"
    if [[ ! -d $d ]]; then
      if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        log::info "  [DRY RUN] Would create directory $d"
      else
        $SUDO_CMD mkdir -p "$d"
      fi
    fi
  done
}

hldirs::create_service_directories() {
  log::info "Creating service-specific directories..."

  local dirs=(
    "${CONFIGS_ROOT}/caddy/conf" "${SITES_ROOT}/caddy/site" "${VOLUMES_ROOT}/caddy/data" "${VOLUMES_ROOT}/caddy/config"
    "${CONFIGS_ROOT}/adguardhome/conf" "${VOLUMES_ROOT}/adguardhome/data"
    "${CONFIGS_ROOT}/unbound/conf"
    "${VOLUMES_ROOT}/uptime-kuma/data"
    "${CONFIGS_ROOT}/netdata/conf" "${VOLUMES_ROOT}/netdata/lib" "${VOLUMES_ROOT}/netdata/cache"
    "${CONFIGS_ROOT}/homepage/conf" "${VOLUMES_ROOT}/homepage/icons" "${VOLUMES_ROOT}/homepage/images" "${VOLUMES_ROOT}/homepage/logs"
    "${CONFIGS_ROOT}/filebrowser/conf" "${VOLUMES_ROOT}/filebrowser"
    "${VOLUMES_ROOT}/portainer"
    "${CONFIGS_ROOT}/jellyfin/conf" "${VOLUMES_ROOT}/jellyfin/cache" "${VOLUMES_ROOT}/jellyfin/data" "${VOLUMES_ROOT}/jellyfin/log"
    "${VOLUMES_ROOT}/gluetun"
    "${VOLUMES_ROOT}/qbittorrent"
    "${VOLUMES_ROOT}/prowlarr" "${VOLUMES_ROOT}/sonarr" "${VOLUMES_ROOT}/radarr" "${VOLUMES_ROOT}/lidarr" "${VOLUMES_ROOT}/readarr" "${VOLUMES_ROOT}/bazarr" "${VOLUMES_ROOT}/recyclarr"
  )

  local d
  for d in "${dirs[@]}"; do
    if [[ ! -d $d ]]; then
      if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        log::info "  [DRY RUN] Would create directory $d"
      else
        $SUDO_CMD mkdir -p "$d"
      fi
    fi
  done
}

hldirs::fix_permissions() {
  local target_user="${SUDO_USER:-$USER}"
  local target_uid
  target_uid=$(id -u "$target_user")
  local target_gid
  target_gid=$(id -g "$target_user")

  log::info "Fixing ownership to $target_user ($target_uid:$target_gid)..."

  local roots=(
    "$DATA_ROOT"
    "$CONFIGS_ROOT"
    "$VOLUMES_ROOT"
    "$SITES_ROOT"
  )

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log::info "  [DRY RUN] Would adjust ownership and permissions for: ${roots[*]}"
    return 0
  fi

  local r
  for r in "${roots[@]}"; do
    if [[ -d $r ]]; then
      $SUDO_CMD chown -R "${target_uid}:${target_gid}" "$r"
      $SUDO_CMD find "$r" -type d -exec chmod 755 {} +
      # Only apply files chmod to DATA_ROOT to avoid breaking config key permissions
      if [[ "$r" == "$DATA_ROOT" ]]; then
        $SUDO_CMD find "$r" -type f -exec chmod 644 {} +
      fi
    fi
  done
}

main() {
  banner::print "homelab dirs"

  hldirs::create_infrastructure
  hldirs::create_media_structure
  hldirs::create_service_directories
  hldirs::fix_permissions

  log::info "Homelab directory setup completed."
}

main "$@"
