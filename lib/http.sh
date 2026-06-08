#!/usr/bin/env bash
# HTTP helpers built on curl.

HTTP_RETRIES="${HTTP_RETRIES:-3}"
HTTP_RETRY_DELAY="${HTTP_RETRY_DELAY:-5}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-15}"
HTTP_MAX_TIME="${HTTP_MAX_TIME:-300}"
HTTP_API_TIMEOUT="${HTTP_API_TIMEOUT:-10}"

http::api_get() {
  local url="${1:?http::api_get requires a URL}"
  shift
  local body code
  body=$(mktemp)
  trap 'rm -f "$body"' RETURN

  if ! code=$(curl -sfL --max-time "$HTTP_API_TIMEOUT" "$@" \
    -o "$body" -w '%{http_code}' "$url"); then
    case "$code" in
      403) log::error "HTTP 403 (rate-limited or auth required): $url" ;;
      404) log::error "HTTP 404: $url" ;;
      *) log::error "HTTP GET failed (code=${code:-0}): $url" ;;
    esac
    return 1
  fi
  cat "$body"
}

http::download() {
  local url="${1:?http::download requires a URL}"
  local dest="${2:-$(basename "$url")}"

  mkdir -p "$(dirname "$dest")"
  log::info "Downloading: $url -> $dest"

  if ! curl -fsSL -C - \
    --retry "$HTTP_RETRIES" \
    --retry-delay "$HTTP_RETRY_DELAY" \
    --retry-connrefused \
    --connect-timeout "$HTTP_TIMEOUT" \
    --max-time "$HTTP_MAX_TIME" \
    -o "$dest" "$url"; then
    log::error "Download failed: $url"
    return 1
  fi

  if [[ ! -s $dest ]]; then
    log::error "Download produced empty file: $dest"
    rm -f "$dest"
    return 1
  fi
}
