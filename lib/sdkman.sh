#!/usr/bin/env bash
# Wrapper around SDKMAN! for unattended installation of Java/Maven/Gradle/etc.

export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

sdkman::_load() {
  local init="${SDKMAN_DIR}/bin/sdkman-init.sh"
  [[ -f $init ]] || {
    log::error "SDKMAN init missing at $init"
    return 1
  }
  set +u
  # shellcheck source=/dev/null
  source "$init"
  set -u
}

sdkman::setup() {
  os::check_dependency zip unzip curl || return 1

  if [[ ! -d $SDKMAN_DIR ]]; then
    log::info "Installing SDKMAN!..."
    curl -s https://get.sdkman.io | bash || {
      log::error "SDKMAN install failed"
      return 1
    }
  fi

  sdkman::_load || return 1

  local config="${SDKMAN_DIR}/etc/config"
  [[ -f $config ]] && sed -i 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "$config"

  log::info "Updating SDKMAN..."
  set +u
  sdk selfupdate force > /dev/null 2>&1 || log::warn "SDKMAN self-update failed"
  set -u
}

# Install candidates listed in apps/<list_name>/sdkman.txt.
# File format: candidate|version|default (default is true or false)
sdkman::install_from_list() {
  local list_name="${1:?sdkman::install_from_list requires a list name}"
  local list="${DOTFILES_ROOT}/apps/${list_name}/sdkman.txt"
  [[ -f $list ]] || {
    log::error "List not found: $list"
    return 1
  }

  sdkman::setup || return 1
  log::info "Processing SDKMAN list: $list_name"

  set +u
  local default_cand="" default_ver=""

  local raw_cand raw_ver raw_def
  while IFS='|' read -r raw_cand raw_ver raw_def || [[ -n $raw_cand ]]; do
    local cand ver def
    cand=$(string::trim "$raw_cand")
    ver=$(string::trim "$raw_ver")
    def=$(string::trim "$raw_def")
    [[ -z $cand || $cand =~ ^# ]] && continue

    if [[ -d "${SDKMAN_DIR}/candidates/${cand}/${ver}" ]]; then
      log::debug "Already installed: ${cand} ${ver}"
    else
      log::info "Installing ${cand} ${ver}..."
      sdk install "$cand" "$ver" || log::warn "Install failed: ${cand} ${ver}"
    fi

    [[ $def == "true" ]] && {
      default_cand="$cand"
      default_ver="$ver"
    }
  done < "$list"

  if [[ -n $default_cand && -d "${SDKMAN_DIR}/candidates/${default_cand}/${default_ver}" ]]; then
    log::info "Setting default: ${default_cand} ${default_ver}"
    sdk default "$default_cand" "$default_ver" > /dev/null
  fi

  sdk flush archives
  set -u
  log::info "SDKMAN list '$list_name' complete"
}
