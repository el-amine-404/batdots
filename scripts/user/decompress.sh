#!/usr/bin/env bash
# scripts/user/decompress.sh -- Extract any common archive/compressed file into
# its own sibling directory '<name>_decompressed/'.
#
# Extraction tools are NOT installed here; they are provisioned by bootstrap
# (config/packages/core.txt). A missing tool is a hard failure.
#
# Supported extensions and what each one is:
#
#   Tar archives (a "Tape ARchive" -- bundles files, then an optional compressor
#   is layered on top; we extract both layers in one pass):
#     .tar                       uncompressed tarball
#     .tar.gz  .tgz  .taz        gzip            -- Lempel-Ziv (LZ77)
#     .tar.bz2 .tbz .tbz2 .tb2 .tz2  bzip2       -- Burrows-Wheeler + Huffman
#     .tar.xz  .txz              xz              -- LZMA2
#     .tar.lzma .tlz             lzma            -- legacy LZMA (xz predecessor)
#     .tar.lz                    lzip            -- LZMA container
#     .tar.lzo                   lzop            -- LZO (fast, low ratio)
#     .tar.zst .tzst             zstd            -- Zstandard (LZ77 + FSE/huff0)
#     .tar.Z   .tZ  .taZ         compress        -- adaptive LZW (decoded via gzip)
#
#   Single-stream compressors (one file in, one file out -- no archive layer):
#     .gz  .z                    gzip
#     .bz2                       bzip2
#     .xz                        xz
#     .lzma                      lzma (legacy)
#     .Z                         compress / LZW (decoded via gzip)
#
#   Multi-file archive containers:
#     .zip                       PKZIP container (unzip)
#     .7z                        7-Zip container (7z, from p7zip-full)
#     .rar                       Roshal Archive (extracted with 7zz, from 7zip)
#     .pax                       POSIX Portable Archive eXchange (pax)
#     .dmg                       Apple Disk Image -- extracted, not mounted (7z)

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

DEC_SRC=""
DEC_DEST=""

dec::usage() {
  cat << EOF
Usage: $(basename "$0") ARCHIVE

Extracts ARCHIVE into a sibling directory '<name>_decompressed/' so files that
lack a top-level folder don't litter the current directory. The required
extraction tool must already be installed (provisioned by bootstrap); a missing
tool is a hard failure.

Supported: .tar[.gz|.bz2|.xz|.lz|.lzma|.lzo|.zst|.Z] and the short forms
(.tgz/.tbz2/.txz/.tlz/.tzst/...), .zip .7z .rar .dmg .pax
.gz .bz2 .xz .lzma .Z

Options:
  -h, --help    Show this help message
EOF
}

dec::parse_args() {
  case "${1:-}" in
    -h | --help)
      dec::usage
      exit 0
      ;;
    "")
      log::error "No archive given"
      dec::usage >&2
      exit 2
      ;;
    -*)
      log::error "Unknown option: $1"
      dec::usage >&2
      exit 2
      ;;
  esac
  [[ $# -eq 1 ]] || log::fatal "Exactly one archive expected, got $#"
  DEC_SRC="$1"
}

# dec::require_tool <command> <package> -- fail unless <command> is on PATH.
# Installation is bootstrap's job, so we only point at the package to install.
dec::require_tool() {
  local cmd="$1" pkg="$2"
  command::exists "$cmd" && return 0
  log::fatal "'$cmd' not found -- install the '$pkg' package (run bootstrap to provision it)"
}

dec::resolve_paths() {
  [[ -f $DEC_SRC ]] || log::fatal "Not a file: $DEC_SRC"
  DEC_SRC=$(realpath -- "$DEC_SRC")
  local name="${DEC_SRC##*/}"
  # Strip a known archive suffix (longest tar.* first) to name the output dir.
  local base="$name"
  base="${base%.tar.*}"
  base="${base%.tar}"
  [[ $base == "$name" ]] && base="${name%.*}"
  DEC_DEST="${DEC_SRC%/*}/${base}_decompressed"

  if [[ -e $DEC_DEST ]]; then
    log::warn "Destination already exists: $DEC_DEST"
    confirmation::seek "Extract into it anyway (existing files may be overwritten)?"
    confirmation::is_confirmed || log::fatal "Aborting to avoid clobbering $DEC_DEST"
  fi
}

# Extract from inside DEC_DEST so single-stream tools (xz/gzip/...) that derive
# their output path from the input land their result in the destination too.
dec::extract() {
  mkdir -p -- "$DEC_DEST"
  cd -- "$DEC_DEST" || log::fatal "Cannot enter $DEC_DEST"

  local src="$DEC_SRC" name="${DEC_SRC##*/}"
  case "$src" in
    *.tar)
      dec::require_tool tar tar
      tar -xvf "$src"
      ;;
    *.tar.bz2 | *.tb2 | *.tbz | *.tbz2 | *.tz2)
      dec::require_tool tar tar
      dec::require_tool bzip2 bzip2
      tar -jxvf "$src"
      ;;
    *.tar.gz | *.taz | *.tgz)
      dec::require_tool tar tar
      dec::require_tool gzip gzip
      tar -zxvf "$src"
      ;;
    *.tar.lz)
      dec::require_tool tar tar
      dec::require_tool lzip lzip
      tar --lzip -xvf "$src"
      ;;
    *.tar.lzma | *.tlz)
      dec::require_tool tar tar
      dec::require_tool xz xz-utils
      tar --lzma -xvf "$src"
      ;;
    *.tar.lzo)
      dec::require_tool tar tar
      dec::require_tool lzop lzop
      tar --lzop -xvf "$src"
      ;;
    *.tar.xz | *.txz)
      dec::require_tool tar tar
      dec::require_tool xz xz-utils
      tar -Jxvf "$src"
      ;;
    *.tar.Z | *.tZ | *.taZ)
      # gzip decompresses legacy .Z, so we avoid depending on 'compress'.
      dec::require_tool tar tar
      dec::require_tool gzip gzip
      gzip -dc -- "$src" | tar -xvf -
      ;;
    *.tar.zst | *.tzst)
      dec::require_tool tar tar
      dec::require_tool zstd zstd
      tar --zstd -xvf "$src"
      ;;
    *.zip)
      dec::require_tool unzip unzip
      unzip -o "$src"
      ;;
    *.xz)
      dec::require_tool xz xz-utils
      xz -dc -- "$src" > "${name%.xz}"
      ;;
    *.lzma)
      dec::require_tool xz xz-utils
      xz --format=lzma -dc -- "$src" > "${name%.lzma}"
      ;;
    *.bz2)
      dec::require_tool bzip2 bzip2
      bzip2 -dc -- "$src" > "${name%.bz2}"
      ;;
    *.gz | *.z)
      dec::require_tool gzip gzip
      gzip -dc -- "$src" > "${name%.*}"
      ;;
    *.Z)
      dec::require_tool gzip gzip
      gzip -dc -- "$src" > "${name%.Z}"
      ;;
    *.dmg)
      # 7z extracts (not mounts) the image; encrypted/odd variants may fail.
      dec::require_tool 7z p7zip-full
      7z x "$src"
      ;;
    *.pax)
      dec::require_tool pax pax
      pax -r < "$src"
      ;;
    *.rar)
      # 7zz handles rar more reliably here than unrar.
      dec::require_tool 7zz 7zip
      7zz x "$src"
      ;;
    *.7z)
      dec::require_tool 7z p7zip-full
      7z x "$src"
      ;;
    *)
      cd - > /dev/null || true
      rmdir -- "$DEC_DEST" 2> /dev/null || true
      log::fatal "Unsupported archive type: $name"
      ;;
  esac
}

main() {
  banner::print "decompress"
  dec::parse_args "$@"
  dec::resolve_paths
  dec::extract
  log::info "Extracted '$DEC_SRC' --> $DEC_DEST"
}

main "$@"
