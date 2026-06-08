#!/usr/bin/env bash
# Sync git-hosted theme/icon/font collections and symlink them into place.
#
# Each line in apps/themes/<list>.txt is `name|url|strategy|dest`:
#   name      directory name under <dest>/.repos/
#   url       git URL to clone or pull
#   strategy  root | collection | flat-collection
#   dest      destination directory relative to $HOME
#
# Strategies:
#   root             repo IS the asset (one symlink to it)
#   collection       repo CONTAINS asset directories (symlink each subdir)
#   flat-collection  repo CONTAINS *.conf files at any depth (symlink each)

# Sync URL into <repo_dir>/<name>, clone if absent, pull if present.
themes::_sync() {
  local repo_dir="$1" name="$2" url="$3"
  local target="${repo_dir}/${name}"

  log::info "Syncing: $name"
  if [[ -d "${target}/.git" ]]; then
    git -C "$target" pull -q --rebase || log::warn "Pull failed: $name"
  elif [[ -d $target ]]; then
    log::warn "$target exists but is not a git repo -- skipping"
  else
    git clone -q --depth=1 "$url" "$target"
  fi
}

# Symlink <source> directory into <install_dir>, skipping junk and conflicts.
themes::_link_dir() {
  local install_dir="$1" source="$2"
  [[ -d $source ]] || return 0
  local name
  name=$(basename "$source")
  case "$name" in .git | src | tests) return 0 ;; esac

  local target="${install_dir}/${name}"
  [[ -L $target ]] && return 0
  if [[ -d $target ]]; then
    log::warn "Conflict: '$name' is a real folder -- skipping link"
    return 0
  fi

  ln -s "$source" "$target"
  log::info "Linked: $name"
}

# Public entry point.
themes::install_from_list() {
  local list_name="${1:?themes::install_from_list requires a list name}"
  local list="${DOTFILES_ROOT}/apps/themes/${list_name}.txt"
  registry::require "$list" || return 1

  log::info "Processing list: $list_name"

  local name url strategy dest
  while IFS='|' read -r name url strategy dest; do
    local install_base="${HOME}/${dest}"
    local repo_store="${install_base}/.repos"
    mkdir -p "$repo_store"

    themes::_sync "$repo_store" "$name" "$url"
    local repo_path="${repo_store}/${name}"

    case "$strategy" in
      root)
        themes::_link_dir "$install_base" "$repo_path"
        ;;
      collection)
        for item in "${repo_path}"/*; do
          themes::_link_dir "$install_base" "$item"
        done
        ;;
      flat-collection)
        log::info "Linking flat .conf files for $name"
        while IFS= read -r f; do
          local fname
          fname=$(basename "$f")
          local target="${install_base}/${fname}"
          [[ -L $target || -f $target ]] && continue
          ln -s "$f" "$target"
          log::info "Linked file: $fname"
        done < <(find "$repo_path" -type f -name '*.conf')
        ;;
      *)
        log::error "Unknown strategy '$strategy' for $name"
        ;;
    esac
  done < <(registry::stream "$list")
}
