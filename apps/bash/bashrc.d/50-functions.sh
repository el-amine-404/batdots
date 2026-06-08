# bashrc.d/50-functions.sh -- small interactive helpers.
# shellcheck shell=bash

# Reload login shell config without spawning a new shell.
rp() {
  local f
  for f in "$HOME/.bash_profile" "$HOME/.profile"; do
    [[ -r "$f" ]] && {
      # shellcheck disable=SC1090
      source "$f"
      return 0
    }
  done
  return 1
}

# Battery state -- function so $(upower -e) is evaluated at *call* time.
battery() {
  cmd::has upower || {
    echo "upower not installed" >&2
    return 1
  }
  local bat
  bat=$(upower -e | grep -i 'BAT' | head -n 1)
  [[ -z $bat ]] && {
    echo "no battery detected" >&2
    return 1
  }
  upower -i "$bat" | grep -E 'state|to\ full|percentage'
}

# Distro-aware system update.
update() {
  if cmd::has apt; then
    sudo apt update && sudo apt upgrade -y
  elif cmd::has dnf; then
    sudo dnf upgrade -y
  elif cmd::has pacman; then
    sudo pacman -Syu --noconfirm
  else
    echo "update: no supported package manager" >&2
    return 1
  fi
}

# Initialize a markdown working dir: assets/images/ + a README.md skeleton.
md() {
  mkdir -p assets/images
  [[ -f README.md ]] || printf '# TITLE GOES HERE, ENJOY YOUR MARKDOWN!!\n' > README.md
}

# QR code -> terminal (UTF-8 ANSI render).
qrt() {
  [[ -z "$1" ]] && {
    echo "Usage: qrt 'your text here'" >&2
    return 1
  }
  cmd::has qrencode || {
    echo "qrencode not installed" >&2
    return 1
  }
  qrencode -t ANSIUTF8 "$*"
}

# QR code -> image, opened with xdg-open, securely shredded after.
qri() {
  [[ -z "$1" ]] && {
    echo "Usage: qri 'your text here'" >&2
    return 1
  }
  cmd::has qrencode || {
    echo "qrencode not installed" >&2
    return 1
  }
  cmd::has xdg-open || {
    echo "xdg-open not installed" >&2
    return 1
  }
  cmd::has shred || {
    echo "shred not installed" >&2
    return 1
  }

  local img
  img=$(mktemp /tmp/qr-XXXXXX.png) || return 1
  # Always clean up, even if the user Ctrl+C's.
  trap 'shred -u "$img" 2>/dev/null; trap - INT TERM EXIT' INT TERM EXIT

  qrencode -o "$img" "$*"
  xdg-open "$img" > /dev/null 2>&1 &
  read -rp "Press [Enter] when done -- file will be securely shredded... "
  shred -u "$img"
  trap - INT TERM EXIT
  echo "removed: $img"
}

# Print a slim PATH listing, one entry per line.
paths() { tr ':' '\n' <<< "$PATH"; }

# Disk usage of a directory's immediate children, largest first.
# Usage: diskusage [-a] [DIR] [DEPTH]   (defaults: current dir, depth 1)
#   -a  also list individual files (not just directory totals)
# Prefers 'dust' (fast, shows progress while scanning). Falls back to du+sort,
# which must scan the whole subtree before printing -- so output appears all at
# once after a pause. -x keeps du on one filesystem (skips /proc, mounts, ...).
# -a forces the du path since it sizes every file, not just directories.
diskusage() {
  local all=0
  [[ ${1:-} == -a ]] && {
    all=1
    shift
  }
  local dir="${1:-.}" depth="${2:-1}"
  if ((all)); then
    printf 'scanning %s (depth %s, one filesystem, incl. files)...\n' "$dir" "$depth" >&2
    du -xah --max-depth="$depth" -- "$dir" 2> /dev/null | sort -rh
  elif cmd::has dust; then
    dust -d "$depth" "$dir"
  else
    printf 'scanning %s (depth %s, one filesystem)...\n' "$dir" "$depth" >&2
    du -xh --max-depth="$depth" -- "$dir" 2> /dev/null | sort -rh
  fi
}

# Pretty `docker ps` / `docker ps -a`. Functions (not aliases) so the Go
# template is interpreted at call time and stays readable.
_dps_fmt() {
  printf '%s' \
    '\nCONTAINER ID\t{{.ID}}' \
    '\nIMAGE\t\t{{.Image}}' \
    '\nCOMMAND\t\t{{.Command}}' \
    '\nCREATED\t\t{{.CreatedAt}}' \
    '\nSTATUS\t\t{{.Status}}' \
    '\nPORTS\t\t{{.Ports}}' \
    '\nNAMES\t\t{{.Names}}' \
    '\nSIZE\t\t{{.Size}}' \
    '\nMOUNTS\t\t{{.Mounts}}' \
    '\nNETWORKS\t{{.Networks}}\n'
}
dps() { docker ps --format "$(_dps_fmt)" "$@"; }
dpsa() { docker ps -a --format "$(_dps_fmt)" "$@"; }

# Swap git author for the *current repo* without touching ~/.gitconfig.
# Reads DOTFILES_GIT_AUTHORS from local/env.sh (gitignored). Example:
#   DOTFILES_GIT_AUTHORS=(
#     "personal:you@users.noreply.github.com:your-handle"
#     "work:you@company.com:Your Real Name"
#   )
git-author() {
  local profile="${1:-}"
  if [[ -z $profile ]]; then
    echo "Usage: git-author <profile>" >&2
    if declare -p DOTFILES_GIT_AUTHORS &> /dev/null; then
      echo "Available profiles:" >&2
      local entry
      for entry in "${DOTFILES_GIT_AUTHORS[@]}"; do
        echo "  - ${entry%%:*}" >&2
      done
    else
      echo "(define DOTFILES_GIT_AUTHORS in local/env.sh)" >&2
    fi
    return 1
  fi
  if ! declare -p DOTFILES_GIT_AUTHORS &> /dev/null; then
    echo "git-author: DOTFILES_GIT_AUTHORS not defined (see local/env.sh)" >&2
    return 1
  fi
  local entry name email match=""
  for entry in "${DOTFILES_GIT_AUTHORS[@]}"; do
    if [[ ${entry%%:*} == "$profile" ]]; then
      match="${entry#*:}"
      email="${match%%:*}"
      name="${match#*:}"
      git config --local user.email "$email"
      git config --local user.name "$name"
      echo "git-author: set $name <$email> for $(git rev-parse --show-toplevel 2> /dev/null || pwd)"
      return 0
    fi
  done
  echo "git-author: profile '$profile' not found in DOTFILES_GIT_AUTHORS" >&2
  return 1
}

# Run a command in every immediate subdirectory, each in a subshell so your cwd
# is untouched. Continues past failures instead of stopping at the first one.
# Usage: runrec <cmd> [args...]      e.g.  runrec git pull
runrec() {
  (($#)) || {
    echo "usage: runrec <cmd> [args...]" >&2
    return 1
  }
  local d
  for d in */; do
    [[ -d $d ]] || continue
    printf '\n== %s ==\n' "$d"
    (cd "$d" && "$@") || echo "  (failed in $d, continuing)" >&2
  done
}
