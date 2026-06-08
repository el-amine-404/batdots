# bashrc.d/60-fnm.sh -- Fast Node Manager (fnm).
# shellcheck shell=bash
# `--use-on-cd` makes fnm switch node version automatically when entering a
# directory with a .node-version / .nvmrc file.

if cmd::has fnm; then
  eval "$(fnm env --use-on-cd)"
fi
