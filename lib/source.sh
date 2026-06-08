#!/usr/bin/env bash
# Type-aware upstream version fetcher. Reads the registry in
# config/versions.conf and dispatches to the right backend.

source::fetch_latest() {
  local prefix="${1:?source::fetch_latest requires a PREFIX}"
  local type_var="${prefix}_TYPE"
  local repo_var="${prefix}_REPO"
  local tag_prefix_var="${prefix}_TAG_PREFIX"
  local bucket_var="${prefix}_BUCKET"
  local obj_prefix_var="${prefix}_OBJ_PREFIX"
  local version_var="${prefix}_VERSION"
  local server_var="${prefix}_SERVER"
  local transform_var="${prefix}_TAG_TRANSFORM"
  local type="${!type_var:-}"

  case "$type" in
    github)
      if [[ "${!transform_var:-}" == "gs-packed" ]]; then
        _source::gs_latest "https://github.com/${!repo_var:-}.git"
      else
        _source::github "${!repo_var:-}" "${!tag_prefix_var:-}"
      fi
      ;;
    gitlab)
      _source::gitlab "${!repo_var:-}" "${!tag_prefix_var:-}" "${!server_var:-gitlab.com}"
      ;;
    bitbucket)
      _source::bitbucket "${!repo_var:-}" "${!tag_prefix_var:-}"
      ;;
    googlestorage)
      _source::googlestorage "${!bucket_var:-}" "${!obj_prefix_var:-}"
      ;;
    git | raw | fixed)
      printf '%s' "${!version_var:-}"
      ;;
    *)
      log::error "source::fetch_latest: unknown type '${type:-unset}' for '${prefix}'"
      return 1
      ;;
  esac
}

# Resolve the base repository URL for a prefix.
source::resolve_repo_url() {
  local prefix="${1:?source::resolve_repo_url requires a PREFIX}"
  local type_var="${prefix}_TYPE"
  local repo_var="${prefix}_REPO"
  local url_var="${prefix}_URL"
  local server_var="${prefix}_SERVER"
  local type="${!type_var:-}"

  case "$type" in
    github) printf 'https://github.com/%s.git' "${!repo_var:-}" ;;
    gitlab) printf 'https://%s/%s.git' "${!server_var:-gitlab.com}" "${!repo_var:-}" ;;
    bitbucket) printf 'https://bitbucket.org/%s.git' "${!repo_var:-}" ;;
    git | raw | fixed) printf '%s' "${!url_var:-}" ;;
    *)
      log::error "source::resolve_repo_url: cannot resolve URL for type '${type:-unset}' (${prefix})"
      return 1
      ;;
  esac
}

# Resolve a specific asset URL, handling pattern replacement if needed.
source::resolve_asset() {
  local prefix="${1:?source::resolve_asset requires a PREFIX}"
  local asset_var="${prefix}_ASSET"
  local url_var="${prefix}_URL"
  local repo_var="${prefix}_REPO"
  local type_var="${prefix}_TYPE"
  local version_var="${prefix}_VERSION"

  local asset="${!asset_var:-}"
  local type="${!type_var:-}"
  local version="${!version_var:-}"

  if [[ -n $asset ]]; then
    local pattern
    case "$type" in
      github) pattern="https://github.com/${!repo_var:-}/releases/download/{TAG}/${asset}" ;;
      *)
        log::error "source::resolve_asset: asset patterns only supported for github type currently"
        return 1
        ;;
    esac
    # Replace {VERSION} and {TAG} in the asset pattern
    local tag_prefix_var="${prefix}_TAG_PREFIX"
    local tag="${!tag_prefix_var:-}${version}"
    local url="${pattern//\{VERSION\}/$version}"
    url="${url//\{TAG\}/$tag}"
    printf '%s' "$url"
  else
    printf '%s' "${!url_var:-}"
  fi
}

source::resolve_asset_url() {
  local prefix="${1:?source::resolve_asset_url requires a PREFIX}"
  local pattern="${2:?source::resolve_asset_url requires a PATTERN}"
  local version="${prefix}_VERSION"
  version="${!version:-}"
  [[ -z $version ]] && {
    log::error "source::resolve_asset_url: ${prefix}_VERSION is unset"
    return 1
  }
  printf '%s' "${pattern//\{VERSION\}/$version}"
}

# Convert Ghostscript packed tag to dotted version.
#   952    -> 9.52
#   9553   -> 9.55.3
#   10070  -> 10.07.0
#   100501 -> 10.05.01
source::gs_packed_to_dotted() {
  local v="${1:?}"
  case ${#v} in
    3) printf '%s.%s' "${v:0:1}" "${v:1:2}" ;;
    4) printf '%s.%s.%s' "${v:0:1}" "${v:1:2}" "${v:3:1}" ;;
    5) printf '%s.%s.%s' "${v:0:2}" "${v:2:2}" "${v:4:1}" ;;
    6) printf '%s.%s.%s' "${v:0:2}" "${v:2:2}" "${v:4:2}" ;;
    *) printf '%s' "$v" ;;
  esac
}

source::gs_dotted_to_packed() {
  local v="${1:?}"
  printf '%s' "${v//./}"
}

_source::github() {
  local repo="${1:-}" tag_prefix="${2:-}"
  [[ -z $repo ]] && return 1
  local tag
  tag=$(github::latest_tag "$repo" "$tag_prefix") || return 1
  tag="${tag#"$tag_prefix"}"
  printf '%s' "${tag#[vV]}"
}

_source::gitlab() {
  local repo="${1:-}" tag_prefix="${2:-}" server="${3:-gitlab.com}"
  [[ -z $repo ]] && return 1
  local tag
  tag=$(gitlab::latest_tag "$repo" "$tag_prefix" "$server") || return 1
  tag="${tag#"$tag_prefix"}"
  printf '%s' "${tag#[vV]}"
}

_source::bitbucket() {
  local repo="${1:-}" tag_prefix="${2:-}"
  [[ -z $repo ]] && return 1
  local tag
  tag=$(git::latest_tag "https://bitbucket.org/${repo}.git" "$tag_prefix") || return 1
  tag="${tag#"$tag_prefix"}"
  printf '%s' "${tag#[vV]}"
}

_source::googlestorage() {
  local bucket="${1:-}" obj_prefix="${2:-}"
  [[ -z $bucket ]] && return 1
  local response version
  response=$(http::api_get \
    "https://storage.googleapis.com/storage/v1/b/${bucket}/o?prefix=${obj_prefix}&fields=items/name") || return 1
  version=$(printf '%s' "$response" \
    | grep -o '"name": *"[^"]*"' \
    | sed "s|\"name\": *\"${obj_prefix}||; s|\".*||; s|\.tar\..*\$||" \
    | grep -E '^[0-9]+(\.[0-9]+)+$' \
    | sort -V \
    | tail -n 1)
  if [[ -z $version ]]; then
    log::error "source: no usable version in GCS bucket '${bucket}/${obj_prefix}'"
    return 1
  fi
  printf '%s' "$version"
}

_source::gs_latest() {
  local url="${1:?}"
  local raw_tags
  raw_tags=$(timeout 15s git ls-remote --tags --refs "$url" 2> /dev/null \
    | awk -F/ '{print $NF}' \
    | grep -E '^gs[0-9]+$' \
    | grep -vEi '(rc|beta|alpha|pre)') || return 1
  [[ -z $raw_tags ]] && {
    log::error "source: no Ghostscript release tags at $url"
    return 1
  }

  local best=""
  while IFS= read -r tag; do
    local dotted
    dotted=$(source::gs_packed_to_dotted "${tag#gs}")
    if [[ -z $best ]]; then
      best="$dotted"
    else
      best=$(printf '%s\n%s\n' "$best" "$dotted" | sort -V | tail -n 1)
    fi
  done <<< "$raw_tags"
  printf '%s' "$best"
}
