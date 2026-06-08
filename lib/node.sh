#!/usr/bin/env bash
# NODE MANAGEMENT (via FNM)
# Uses Fast Node Manager (Rust) for speed

node::setup() {
  if ! command -v fnm > /dev/null; then
    log::info "Installing FNM (Fast Node Manager)..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
  fi

  export PATH="$HOME/.local/bin:$PATH"

  if command -v fnm > /dev/null; then
    eval "$(fnm env --use-on-cd)"
  else
    log::error "FNM installed but not found in PATH."
    return 1
  fi
}

node::install_from_list() {
  local list_name="$1"
  local list_file="${DOTFILES_ROOT}/apps/${list_name}/fnm.txt"

  if [[ ! -f $list_file ]]; then
    log::error "Node Config file not found: $list_file"
    return 1
  fi

  node::setup
  log::info "Processing Node list: $list_name"

  local final_version=""

  while IFS='|' read -r raw_ver raw_def || [[ -n $raw_ver ]]; do

    local ver def
    ver=$(string::trim "$raw_ver")
    def=$(string::trim "$raw_def")

    [[ $ver =~ ^#.*$ ]] || [[ -z $ver ]] && continue

    if fnm list | grep -q "$ver"; then
      log::debug "Node $ver is already installed."
    else
      log::info "Installing Node $ver..."
      fnm install "$ver"
    fi

    if [[ $def == "true" ]]; then
      final_version="$ver"
    fi

  done < "$list_file"

  if [[ -n $final_version ]]; then
    log::info "Setting global default: Node $final_version"
    fnm default "$final_version" > /dev/null
    fnm use "$final_version" > /dev/null
  fi

  log::info "Node setup complete."
}
