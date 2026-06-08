# profile.d/restic.sh -- restic backup defaults.
# shellcheck shell=bash
# Real values live in local/env.sh (gitignored), e.g.:
#   export RESTIC_REPOSITORY="rclone:remote:bucket"
#   export RESTIC_PASSWORD_FILE="$(shell::get_repo_root)/local/restic_pass"
# This file only enforces a sane default location for the password file: the
# repo's own local/restic_pass (env.sh normally exports this already).
: "${RESTIC_PASSWORD_FILE:=$(shell::get_repo_root)/local/restic_pass}"
export RESTIC_PASSWORD_FILE
