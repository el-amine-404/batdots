#!/usr/bin/env bash
# Muslim prayer-time fetchers, cache, and rendering.
#
# Pluggable backends. Add one by:
#   1. Define prayer::backend_<name> <city> <country>; on success, write a
#      normalized cache JSON via prayer::_write_normalized OR
#      prayer::_build_normalized_from_times.
#   2. Append <name> to PRAYER_BACKENDS.
#
# All HTTP traffic uses curl -fsSL (fail on HTTP error, follow redirects,
# verify TLS). The deprecated -k flag from earlier versions is gone --
# disabling cert verification is never traded for convenience.

PRAYER_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
PRAYER_CACHE_FILE="${PRAYER_CACHE_DIR}/prayer_times.json"

PRAYER_BACKENDS=(aladhan habous custom)
PRAYER_DEFAULT_CITY="London"
PRAYER_DEFAULT_COUNTRY="United Kingdom"
PRAYER_ALADHAN_DEFAULT_METHOD=3 # 3 = Muslim World League

# Morocco city -> Habous prayer-times catalog ID. Public and intentionally
# so: the catalog itself is public, the IDs are public. Users with cities
# not in this map can extend DOTFILES_PRAYER_CITY_MAP in local/env.sh as
# "city:id,city2:id2,...". User overrides take precedence.
declare -gA PRAYER_HABOUS_CITY_IDS=(
  ["rabat"]=1
  ["tanger"]=14
  ["tetouan"]=15
  ["larache"]=16
  ["chefchaouen"]=18
  ["al-hoceima"]=23
  ["el-hoceima"]=23
  ["ouezzane"]=29
  ["oujda"]=31
  ["casablanca"]=58
  ["settat"]=61
  ["el-jadida"]=66
  ["fes"]=81
  ["meknes"]=99
  ["marrakech"]=104
  ["safi"]=111
  ["agadir"]=117
)

# ---------------------------------------------------------------------------
# Cache management
# ---------------------------------------------------------------------------

prayer::cache_init() {
  dir::ensure "$PRAYER_CACHE_DIR"
}

# True iff today's cache exists AND was written by the requested backend
# AND matches the requested city/country. Switching any of these refetches.
prayer::cache_is_fresh() {
  local backend="${1:?prayer::cache_is_fresh requires BACKEND}"
  local city="${2:?prayer::cache_is_fresh requires CITY}"
  local country="${3:?prayer::cache_is_fresh requires COUNTRY}"
  [[ -f $PRAYER_CACHE_FILE ]] || return 1

  local stamp
  stamp=$(jq -r '[._cache.date, ._cache.backend, ._cache.city, ._cache.country] | @tsv' \
    "$PRAYER_CACHE_FILE" 2> /dev/null) || return 1

  local cached_date cached_backend cached_city cached_country today
  today=$(date +%Y-%m-%d)
  IFS=$'\t' read -r cached_date cached_backend cached_city cached_country <<< "$stamp"

  [[ $cached_date == "$today" &&
    $cached_backend == "$backend" &&
    $cached_city == "$city" &&
    $cached_country == "$country" ]]
}

prayer::cache_clear() {
  rm -f -- "$PRAYER_CACHE_FILE"
}

# Atomically write content to PRAYER_CACHE_FILE. Used by every backend.
prayer::_write_atomic() {
  local content="${1:?content required}"
  local tmp
  tmp=$(mktemp --tmpdir="$PRAYER_CACHE_DIR" prayer.XXXXXX) || return 1
  printf '%s' "$content" > "$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  mv -- "$tmp" "$PRAYER_CACHE_FILE"
}

# ---------------------------------------------------------------------------
# Location resolution
# ---------------------------------------------------------------------------

# Echoes "city|country" resolved in this order:
#   1. DOTFILES_PRAYER_CITY / DOTFILES_PRAYER_COUNTRY (env)
#   2. GeoIP cache (24h) -> live lookup
#   3. GeoIP fallback
prayer::resolve_location() {
  if [[ -n ${DOTFILES_PRAYER_CITY:-} ]]; then
    printf '%s|%s' \
      "$DOTFILES_PRAYER_CITY" \
      "${DOTFILES_PRAYER_COUNTRY:?DOTFILES_PRAYER_COUNTRY must be set in local/env.sh if CITY is set}"
    return 0
  fi

  local geoip
  if geoip=$(prayer::_geoip_lookup); then
    printf '%s' "$geoip"
    return 0
  fi

  printf '%s|%s' "$PRAYER_DEFAULT_CITY" "$PRAYER_DEFAULT_COUNTRY"
}

prayer::_geoip_cache_file() {
  printf '%s/location.json' "$PRAYER_CACHE_DIR"
}

# 24h cached GeoIP lookup. Returns "city|country" or non-zero.
prayer::_geoip_lookup() {
  local cache_file
  cache_file=$(prayer::_geoip_cache_file)

  local stale=1
  if [[ -f $cache_file ]]; then
    find "$cache_file" -mmin -1440 -print -quit 2> /dev/null | grep -q . && stale=0
  fi

  if ((stale)); then
    local resp
    if resp=$(curl -fsSL --connect-timeout 5 'http://ip-api.com/json' 2> /dev/null); then
      printf '%s' "$resp" > "$cache_file"
    else
      [[ -f $cache_file ]] || return 1
    fi
  fi

  local city country
  IFS=$'\t' read -r city country < <(jq -r \
    '[.city, .country] | @tsv' "$cache_file" 2> /dev/null) || return 1

  [[ -n $city && $city != null && -n $country && $country != null ]] || return 1
  printf '%s|%s' "$city" "$country"
}

# ---------------------------------------------------------------------------
# Backend: aladhan (public API, default)
# ---------------------------------------------------------------------------

prayer::backend_aladhan() {
  local city="${1:?city required}"
  local country="${2:?country required}"
  local method="${DOTFILES_PRAYER_METHOD:?DOTFILES_PRAYER_METHOD must be set in local/env.sh}"

  local url
  url=$(printf 'https://api.aladhan.com/v1/timingsByCity?city=%s&country=%s&method=%s' \
    "$(prayer::_urlencode "$city")" \
    "$(prayer::_urlencode "$country")" \
    "$method")

  log::info "fetching aladhan: ${city}, ${country}"
  local raw
  raw=$(curl -fsSL --connect-timeout 10 "$url") || return 1

  prayer::_write_normalized "$raw" "$city" "$country" "aladhan"
}

# ---------------------------------------------------------------------------
# Backend: habous (Moroccan religious affairs ministry, HTML scraper)
#
# URL template comes from DOTFILES_PRAYER_SCRAPE_URL (set in local/env.sh).
# Must contain {ID} placeholder, replaced with the city's catalog ID.
# ---------------------------------------------------------------------------

# Path to the system trust store, across the distros this repo targets.
prayer::_system_ca_file() {
  local f
  for f in /etc/ssl/certs/ca-certificates.crt \
    /etc/pki/tls/certs/ca-bundle.crt \
    /etc/ssl/cert.pem; do
    [[ -r $f ]] && {
      printf '%s' "$f"
      return 0
    }
  done
  local dir
  dir=$(openssl version -d 2> /dev/null | sed -E 's/.*"(.*)".*/\1/')
  [[ -n $dir && -r "${dir}/cert.pem" ]] && {
    printf '%s' "${dir}/cert.pem"
    return 0
  }
  return 1
}

# Echo the path to a cached PEM of HOST's issuing intermediate CA, discovered
# via the leaf cert's AIA "CA Issuers" pointer. Cached 30 days -- the
# intermediate is stable for years, so a daily run never refetches it.
prayer::_habous_intermediate() {
  local host="${1:?host required}"
  local pem="${PRAYER_CACHE_DIR}/habous_intermediate.pem"

  if [[ -f $pem ]] \
    && find "$pem" -mmin -43200 -print -quit 2> /dev/null | grep -q .; then
    printf '%s' "$pem"
    return 0
  fi

  local leaf aia
  leaf=$(echo | openssl s_client -connect "${host}:443" -servername "$host" 2> /dev/null) || return 1
  aia=$(printf '%s' "$leaf" | openssl x509 -noout -text 2> /dev/null \
    | grep -i 'CA Issuers' | grep -oiE 'https?://[^[:space:]]+' | head -n 1)
  [[ -n $aia ]] || return 1

  # AIA-served certs are binary DER (with null bytes), so download to a file
  # rather than a shell variable -- command substitution would strip the
  # nulls and corrupt the cert. Accept DER or, rarely, PEM.
  local raw tmp
  raw=$(mktemp --tmpdir="$PRAYER_CACHE_DIR" habous_aia.XXXXXX) || return 1
  tmp=$(mktemp --tmpdir="$PRAYER_CACHE_DIR" habous_ca.XXXXXX) || {
    rm -f -- "$raw"
    return 1
  }

  if curl -fsSL --connect-timeout 10 "$aia" -o "$raw" \
    && { openssl x509 -inform DER -in "$raw" -out "$tmp" 2> /dev/null \
      || openssl x509 -in "$raw" -out "$tmp" 2> /dev/null; } \
    && mv -- "$tmp" "$pem"; then
    rm -f -- "$raw"
    printf '%s' "$pem"
    return 0
  fi

  rm -f -- "$raw" "$tmp"
  return 1
}

prayer::backend_habous() {
  local city="${1:?city required}"
  local country="${2:-Morocco}"

  local url_template="${DOTFILES_PRAYER_SCRAPE_URL:-}"
  [[ -n $url_template ]] || {
    log::error "habous backend needs DOTFILES_PRAYER_SCRAPE_URL set (template with {ID})"
    return 1
  }

  local id
  id=$(prayer::_habous_resolve_city_id "$city") || {
    log::error "no habous ID known for city: $city"
    return 1
  }

  local url="${url_template/\{ID\}/$id}"
  log::info "fetching habous: ${city} (id=${id})"

  # habous.gov.ma serves an incomplete TLS chain (leaf cert only, no
  # intermediate), so curl cannot reach a trusted root on its own. Repair
  # the chain by fetching the issuing intermediate via the leaf's AIA
  # pointer and verifying against system roots + that intermediate. We never
  # disable verification (no -k); we supply the bytes the server omits.
  command::exists openssl || {
    log::error "habous backend needs openssl to repair the server's incomplete TLS chain"
    return 1
  }

  local host="${url#*://}"
  host="${host%%/*}"
  host="${host%%:*}"

  local sysca inter
  sysca=$(prayer::_system_ca_file) || {
    log::error "cannot locate the system CA bundle"
    return 1
  }
  inter=$(prayer::_habous_intermediate "$host") || {
    log::error "could not obtain intermediate CA for ${host} (incomplete server chain)"
    return 1
  }

  local html
  html=$(curl -fsSL -A "Mozilla/5.0" --connect-timeout 10 \
    --cacert <(cat "$sysca" "$inter") "$url") || return 1

  local times
  times=$(prayer::_habous_extract_times "$html" "$url") || {
    log::error "could not parse habous response for ${city}"
    return 1
  }

  prayer::_build_normalized_from_times "$times" "$city" "$country" "habous"
}

# Resolve city name -> ID via user override map, then built-in table.
prayer::_habous_resolve_city_id() {
  local city="${1,,}"
  city="${city// /-}"
  city="${city//è/e}"
  city="${city//é/e}"

  if [[ -n ${DOTFILES_PRAYER_CITY_MAP:-} ]]; then
    local override
    override=$(printf '%s' "$DOTFILES_PRAYER_CITY_MAP" \
      | tr ',' '\n' \
      | awk -F: -v c="$city" 'tolower($1)==c {print $2; exit}')
    [[ -n $override ]] && {
      printf '%s' "$override"
      return 0
    }
  fi

  [[ -n ${PRAYER_HABOUS_CITY_IDS[$city]:-} ]] || return 1
  printf '%s' "${PRAYER_HABOUS_CITY_IDS[$city]}"
}

# Extract 6 prayer times (HH:MM) from a Habous HTML or API response.
# Two response shapes are supported: the JSON-ish /horaire-api response
# (single line) and the rendered HTML calendar (one row per day, today
# matched on day-of-month).
prayer::_habous_extract_times() {
  local html="$1" url="$2"
  local row

  if [[ $url == *"horaire-api"* ]]; then
    row=$(printf '%s' "$html" | tr -d '\n\r')
  else
    local day
    day=$(date +%-d)
    row=$(printf '%s' "$html" | tr -d '\n\r' \
      | sed 's/<tr/\n<tr/g' \
      | grep -iE "<td[^>]*>[^<]+<\/td>[[:space:]]*<td[^>]*>[^<]+<\/td>[[:space:]]*<td[^>]*>[[:space:]]*${day}([[:space:]]+|$)<\/td>" \
      | head -n 1)
  fi

  [[ -n $row ]] || return 1

  local times=() t
  while read -r t; do
    times+=("${t// /}")
  done < <(printf '%s' "$row" | grep -oE '[0-9]{1,2}[[:space:]]*:[[:space:]]*[0-9]{2}')

  ((${#times[@]} >= 6)) || return 1

  printf '%s %s %s %s %s %s' \
    "${times[0]}" "${times[1]}" "${times[2]}" "${times[3]}" "${times[4]}" "${times[5]}"
}

# ---------------------------------------------------------------------------
# Backend: custom (user-supplied hook)
#
# Define `prayer::user_backend <city> <country>` in local/env.sh. Hook is
# responsible for writing the normalized JSON via the public helpers
# (prayer::_write_normalized or prayer::_build_normalized_from_times).
# ---------------------------------------------------------------------------

prayer::backend_custom() {
  if command::exists prayer::user_backend; then
    prayer::user_backend "$@"
  else
    log::error "no custom backend defined -- set prayer::user_backend in local/env.sh"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Normalized cache writer (called by backends)
# ---------------------------------------------------------------------------

# Stamp an existing aladhan-shape JSON response with ._cache metadata and
# atomically write it to PRAYER_CACHE_FILE.
prayer::_write_normalized() {
  local raw="$1" city="$2" country="$3" backend="$4"
  local stamped
  stamped=$(printf '%s' "$raw" | jq \
    --arg city "$city" \
    --arg country "$country" \
    --arg backend "$backend" \
    --arg date "$(date +%Y-%m-%d)" \
    '. + {_cache: {backend: $backend, date: $date, city: $city, country: $country}}') \
    || return 1
  prayer::_write_atomic "$stamped"
}

# Build a normalized JSON from 6 extracted times and atomically write it.
prayer::_build_normalized_from_times() {
  local times_str="$1" city="$2" country="$3" backend="$4"
  local fajr sunrise dhuhr asr maghrib isha
  read -r fajr sunrise dhuhr asr maghrib isha <<< "$times_str"

  local payload
  payload=$(jq -n \
    --arg fajr "$fajr" --arg sunrise "$sunrise" --arg dhuhr "$dhuhr" \
    --arg asr "$asr" --arg maghrib "$maghrib" --arg isha "$isha" \
    --arg city "$city" --arg country "$country" \
    --arg backend "$backend" \
    --arg date "$(date +%Y-%m-%d)" \
    --arg readable "$(date '+%d %b %Y')" \
    '{
      data: {
        timings: {
          Fajr: $fajr, Sunrise: $sunrise, Dhuhr: $dhuhr,
          Asr: $asr, Maghrib: $maghrib, Isha: $isha
        },
        date: { readable: $readable, gregorian: { date: $date } },
        meta: { method: { name: $backend } }
      },
      _cache: { backend: $backend, date: $date, city: $city, country: $country }
    }') || return 1
  prayer::_write_atomic "$payload"
}

# jq-based URL encoder -- avoids depending on python or jq's older quirks.
prayer::_urlencode() {
  jq -rn --arg s "${1:-}" '$s|@uri'
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

prayer::default_backend() {
  printf '%s' "${DOTFILES_PRAYER_BACKEND:?DOTFILES_PRAYER_BACKEND must be set in local/env.sh}"
}

prayer::is_known_backend() {
  local candidate="${1:-}"
  local b
  for b in "${PRAYER_BACKENDS[@]}"; do
    [[ $b == "$candidate" ]] && return 0
  done
  return 1
}

prayer::fetch() {
  local backend="${1:?backend required}"
  local city="${2:?city required}"
  local country="${3:?country required}"

  prayer::is_known_backend "$backend" || {
    log::error "unknown backend '${backend}'. Known: ${PRAYER_BACKENDS[*]}"
    return 1
  }
  "prayer::backend_${backend}" "$city" "$country"
}

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

# Print today's prayer times from cache. Single jq call extracts all
# fields at once, avoiding the per-prayer jq invocation of the old code.
prayer::render() {
  local from_cache="${1:-false}"
  [[ -f $PRAYER_CACHE_FILE ]] || {
    log::error "no cache to render"
    return 1
  }

  local row
  row=$(jq -r '[
    .data.date.readable,
    ._cache.city,
    ._cache.country,
    .data.meta.method.name,
    .data.timings.Fajr,
    .data.timings.Sunrise,
    .data.timings.Dhuhr,
    .data.timings.Asr,
    .data.timings.Maghrib,
    .data.timings.Isha
  ] | @tsv' "$PRAYER_CACHE_FILE") || return 1

  local date city country method fajr sunrise dhuhr asr maghrib isha
  IFS=$'\t' read -r date city country method fajr sunrise dhuhr asr maghrib isha <<< "$row"

  local suffix=""
  [[ $from_cache == true ]] && suffix=" (cached)"

  printf '\n%s%sPrayer Times -- %s%s%s\n' \
    "$BOLD" "$FG_CYAN" "$date" "$RESET" "$suffix"
  printf '%sLocation: %s, %s (backend: %s)%s\n' \
    "$DIM" "$city" "$country" "$method" "$RESET"
  printf -- '----------------------------------------\n'

  local rows=(
    "Fajr|$fajr"
    "Shuruq|$sunrise"
    "Dhuhr|$dhuhr"
    "Asr|$asr"
    "Maghrib|$maghrib"
    "Isha|$isha"
  )
  local entry name time
  for entry in "${rows[@]}"; do
    name="${entry%%|*}"
    time="${entry#*|}"
    printf '%s%-10s%s %s\n' "$BOLD" "$name" "$RESET" "$time"
  done
  printf '\n'
}
