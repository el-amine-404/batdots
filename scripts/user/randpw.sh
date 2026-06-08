#!/usr/bin/env bash
#                          __
#    _________ _____  ____/ /___ _      __
#   / ___/ __ `/ __ \/ __  / __ \ | /| / /
#  / /  / /_/ / / / / /_/ / /_/ / |/ |/ /
# /_/   \__,_/_/ /_/\__,_/ .___/|__/|__/
#                       /_/
#
# a script that generates random passwords
# some alternative online tools are:
#     + ttps://www.avast.com/random-password-generator
#     + ttps://www.lastpass.com/features/password-generator
#     + ttps://1password.com/password-generator/
#     + ttps://bitwarden.com/password-generator/
#     + ttps://www.dashlane.com/features/password-generator
#     + ttps://my.norton.com/extspa/passwordmanager
#
# source: https://www.howtogeek.com/30184/10-ways-to-generate-a-random-password-from-the-command-line/

set -Eeuo pipefail

RANDPW_DEFAULT_LENGTH=30
RANDPW_ALNUM='A-Za-z0-9'
RANDPW_SYMBOLS='!@#$%^&*()-_=+[]{};:,.<>?'

randpw::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [LENGTH]

Generate a random password from /dev/urandom (default length: $RANDPW_DEFAULT_LENGTH).

Options:
  -a, --alnum   Letters and digits only (no symbols)
  -h, --help    Show this help message
EOF
}

randpw::generate() {
  local length="$1" charset="$2"
  # head closes the pipe early, so tr takes SIGPIPE -- expected, hence '|| true'
  # under pipefail. LC_ALL=C keeps tr byte-oriented regardless of locale.
  LC_ALL=C tr -dc "$charset" < /dev/urandom 2> /dev/null | head -c "$length" || true
  echo
}

main() {
  local length="$RANDPW_DEFAULT_LENGTH"
  local charset="${RANDPW_ALNUM}${RANDPW_SYMBOLS}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a | --alnum) charset="$RANDPW_ALNUM" ;;
      -h | --help)
        randpw::usage
        exit 0
        ;;
      -*)
        echo "Unknown option: $1" >&2
        randpw::usage >&2
        exit 1
        ;;
      *) length="$1" ;;
    esac
    shift
  done

  [[ $length =~ ^[0-9]+$ && $length -gt 0 ]] || {
    echo "length must be a positive integer (got '$length')" >&2
    exit 1
  }

  randpw::generate "$length" "$charset"
}

main "$@"
