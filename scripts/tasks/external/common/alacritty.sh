#!/usr/bin/env bash

set -Eeuo pipefail
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/config/versions.conf"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/build.sh"

banner::print "build-alacritty"

# 1. Resolve Version
VERSION=$(build::resolve_version "ALACRITTY")

# 2. Idempotency Check
build::binary_already_installed "alacritty" "${VERSION#v}" 'alacritty --version | awk "{print \$2}"' && exit 0

# 3. Cleanup conflicting system versions
build::purge_system_package "alacritty"
build::purge_system_package "alacritty-common"

# 4. Setup Build Environment
export CARGO_HOME="${HOME}/.cargo"
if [[ -f "${CARGO_HOME}/env" ]]; then source "${CARGO_HOME}/env"; fi

# 5. Source Acquisition
src_dir=$(build::fetch_git "alacritty" "https://github.com/alacritty/alacritty.git" "$VERSION")

(
  cd "$src_dir" || exit 1
  log::info "Compiling Alacritty (Release Mode)..."
  cargo build --release

  # 6. Install Binary
  log::info "Installing to /usr/local/bin/alacritty..."
  $SUDO_CMD cp target/release/alacritty /usr/local/bin/alacritty
  $SUDO_CMD chmod +x /usr/local/bin/alacritty

  # 7. System Integrations
  log::info "Installing System Integrations..."
  $SUDO_CMD tic -xe alacritty,alacritty-direct extra/alacritty.info
  $SUDO_CMD cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg

  # Update desktop file with correct path
  sed -i "s|^Exec=alacritty|Exec=/usr/local/bin/alacritty|" extra/linux/Alacritty.desktop
  $SUDO_CMD desktop-file-install --dir=/usr/local/share/applications --set-icon="Alacritty" extra/linux/Alacritty.desktop
  $SUDO_CMD update-desktop-database

  # Man Pages
  MAN_DIR="/usr/local/share/man"
  $SUDO_CMD mkdir -p "${MAN_DIR}/man1" "${MAN_DIR}/man5"
  scdoc < extra/man/alacritty.1.scd | gzip -c | $SUDO_CMD tee "${MAN_DIR}/man1/alacritty.1.gz" > /dev/null
  scdoc < extra/man/alacritty-msg.1.scd | gzip -c | $SUDO_CMD tee "${MAN_DIR}/man1/alacritty-msg.1.gz" > /dev/null
  scdoc < extra/man/alacritty.5.scd | gzip -c | $SUDO_CMD tee "${MAN_DIR}/man5/alacritty.5.gz" > /dev/null
)

build::verify_binary "alacritty"
build::cleanup "alacritty"
log::info "alacritty ${VERSION} done"
