#!/usr/bin/env bash
# Font installation. Driven by FONT_COMPONENTS in config/versions.conf.

# Install/update a font using its registry prefix.
# Usage: fonts::install_from_registry "FONT_HACK"
fonts::install_from_registry() {
  local prefix="${1:?fonts::install_from_registry requires a PREFIX}"
  local type_var="${prefix}_TYPE"
  local repo_var="${prefix}_REPO"
  local asset_var="${prefix}_ASSET"
  local version_var="${prefix}_VERSION"
  local tag_prefix_var="${prefix}_TAG_PREFIX"
  local type="${!type_var:-}"
  local repo="${!repo_var:-}"
  local asset_pattern="${!asset_var:-}"
  local version="${!version_var:-}"
  local tag_prefix="${!tag_prefix_var:-}"

  local target_dir="${HOME}/.local/share/fonts/${prefix#FONT_}"
  local version_file="${target_dir}/.version"

  if [[ -f $version_file ]] && grep -qx "$version" "$version_file"; then
    log::debug "Skipping $prefix: already at $version"
    return 0
  fi

  local url
  case "$type" in
    github)
      local asset_name
      asset_name=$(source::resolve_asset_url "$prefix" "$asset_pattern") || return 1
      url="https://github.com/${repo}/releases/download/${tag_prefix}${version}/${asset_name}"
      ;;
    raw)
      local branch_var="${prefix}_BRANCH" path_var="${prefix}_PATH"
      url="https://raw.githubusercontent.com/${repo}/${!branch_var:-main}/${!path_var:-}"
      ;;
    *)
      log::error "fonts: unsupported type '$type' for $prefix"
      return 1
      ;;
  esac

  log::info "Installing $prefix ($version)..."
  local tmp_file
  tmp_file=$(mktemp)
  trap 'rm -f "$tmp_file"' RETURN

  http::download "$url" "$tmp_file" || return 1

  [[ -d $target_dir ]] && rm -rf "${target_dir:?}"
  mkdir -p "$target_dir"
  fonts::_extract_or_copy "$tmp_file" "$target_dir" "$(basename "$url")"
  printf '%s\n' "$version" > "$version_file"
}

fonts::_extract_or_copy() {
  local src="$1" dest_dir="$2" filename="$3"
  if file "$src" | grep -q "Zip archive"; then
    local tmp
    tmp=$(mktemp -d)
    if unzip -q "$src" -d "$tmp"; then
      find "$tmp" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec mv {} "$dest_dir" \;
    else
      log::warn "unzip failed for $src"
    fi
    rm -rf "$tmp"
  else
    cp "$src" "${dest_dir}/${filename}"
  fi
}

fonts::refresh_cache() {
  if ! command -v fc-cache &> /dev/null; then
    log::warn "fc-cache not found -- restart your session for font changes to apply"
    return 0
  fi
  log::info "Refreshing font cache..."
  fc-cache -f > /dev/null && log::info "Font cache updated"
}

fonts::preview() {
  local font="${1:?fonts::preview requires a font file}"
  command -v fc-scan &> /dev/null || {
    log::error "fontconfig (fc-scan) required"
    return 1
  }
  fc-scan "$font" | grep -E "family:|style:|fullname:"
}
