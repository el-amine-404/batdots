#!/usr/bin/env bash
# Notification helpers for Pushover and Discord.
#
# Depends on secrets in local/env.sh:
#   PUSHOVER_API_KEY
#   PUSHOVER_USER_KEY
#   RESTIC_DISCORD_WEBHOOK (generic name for Discord alerts)

notification::pushover() {
  local title="${1:-Notification}"
  local message="${2:?notification::pushover requires a message}"
  local device="${PUSHOVER_DEVICE:-}"

  # Load local env if not already loaded to get keys
  declare -F shell::source_env > /dev/null && shell::source_env

  [[ -z ${PUSHOVER_API_KEY:-} || -z ${PUSHOVER_USER_KEY:-} ]] && {
    log::warn "Pushover keys not set, skipping notification"
    return 0
  }

  log::info "Sending Pushover notification: $title"
  curl -s \
    -F "token=${PUSHOVER_API_KEY}" \
    -F "user=${PUSHOVER_USER_KEY}" \
    -F "device=${device}" \
    -F "title=${title}" \
    -F "message=${message}" \
    "https://api.pushover.net/1/messages.json" > /dev/null 2>&1 || {
    log::error "Pushover notification failed"
    return 1
  }
}

notification::discord() {
  local title="${1:-Notification}"
  local message="${2:?notification::discord requires a message}"
  local webhook="${3:-${DISCORD_WEBHOOK:-}}"

  [[ -z $webhook ]] && {
    log::warn "Discord webhook not set, skipping notification"
    return 0
  }

  log::info "Sending Discord notification: $title"

  # Format as a simple embed-like JSON
  local payload
  payload=$(printf '{"content": "**%s**\n%s"}' "$title" "$message")

  curl -s -X POST -H "Content-Type: application/json" \
    -d "$payload" "$webhook" > /dev/null 2>&1 || {
    log::error "Discord notification failed"
    return 1
  }
}
