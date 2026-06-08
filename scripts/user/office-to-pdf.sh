#!/usr/bin/env bash
# scripts/user/office-to-pdf.sh -- Convert office documents to PDF, then archive
# the originals. Uses a self-hosted Gotenberg instance when reachable, otherwise
# falls back to local LibreOffice -- pick explicitly with --backend.
#
# Inputs may be individual files, a list of files, and/or directories. With no
# argument it processes the current directory. Directory search is shallow by
# default; pass -r to recurse. For each document it writes <name>.pdf beside it,
# moves the original into a per-directory 'original_ms_files/' folder, and
# tar.xz-archives those folders at the end.
#
# Output is PDF/A (archival) by default; pass --plain for ordinary PDF.
#   * Gotenberg backend   -> reliable PDF/A-2b (pdfa form field).
#   * LibreOffice backend -> plain PDF only (a warning is shown when PDF/A was
#     requested). Use the gotenberg backend when you need archival PDF/A.
#
# Gotenberg endpoint comes from DOTFILES_GOTENBERG_URL (see local/env.sh.example).

set -Eeuo pipefail

source "${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}/lib/bash-utilities.sh"

GOT_URL="${DOTFILES_GOTENBERG_URL:?DOTFILES_GOTENBERG_URL must be set in local/env.sh}"
OFFICE_BACKEND="auto" # auto | gotenberg | libreoffice
OFFICE_PDFA="PDF/A-2b"
OFFICE_FORCE=0
OFFICE_RECURSIVE=0
OFFICE_CONVERTED=0
OFFICE_FAILED=0
OFFICE_SKIPPED=0
OFFICE_EXTS=(doc docx docm dot dotx dotm rtf odt ott
  xls xlsx xlsm xlt xltx xltm ods csv ots
  ppt pptx pptm pps ppsx pot potx potm odp otp)
declare -a OFFICE_POS=()
declare -a OFFICE_FILES=()
declare -a OFFICE_NAME_TESTS=()
declare -A OFFICE_ORIG_DIRS=()
declare -A OFFICE_STEM_COUNT=()

office::usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [FILE|DIR]...

Converts office documents to PDF via Gotenberg or LibreOffice, then moves each
original into 'original_ms_files/' and tar.xz-archives those folders.

Targets:
  (none)             process the current directory (shallow)
  FILE...            convert exactly the given files
  DIR...             convert matching documents found inside (case-insensitive)

Options:
      --backend B    auto (default), gotenberg, or libreoffice
                     auto = Gotenberg if reachable, else LibreOffice
  -r, --recursive    Recurse into subdirectories of any DIR target
      --plain        Produce ordinary PDF instead of PDF/A (archival)
  -f, --force        Overwrite an existing <name>.pdf (default: skip it)
  -n, --dry-run      Show what would happen without converting or moving
  -h, --help         Show this help message

Gotenberg endpoint: \$DOTFILES_GOTENBERG_URL (currently: ${GOT_URL})
EOF
}

office::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend)
        shift
        OFFICE_BACKEND="${1:?--backend needs a value}"
        ;;
      -r | --recursive) OFFICE_RECURSIVE=1 ;;
      --plain) OFFICE_PDFA="" ;;
      -f | --force) OFFICE_FORCE=1 ;;
      -n | --dry-run) export DRY_RUN=1 ;;
      -h | --help)
        office::usage
        exit 0
        ;;
      --)
        shift
        OFFICE_POS+=("$@")
        break
        ;;
      -*)
        log::error "Unknown option: $1"
        office::usage >&2
        exit 2
        ;;
      *) OFFICE_POS+=("$1") ;;
    esac
    shift
  done
}

office::require_deps() {
  local tool
  for tool in tar xz; do
    command::exists "$tool" || log::fatal "$tool not found -- install it (run bootstrap to provision it)"
  done
}

office::gotenberg_reachable() {
  curl --fail --silent --show-error --connect-timeout 5 --max-time 10 "${GOT_URL}/health" > /dev/null 2>&1
}

# Resolve OFFICE_BACKEND to a concrete value, verify its dependencies, and
# downgrade PDF/A if the LibreOffice path can't produce it.
office::select_backend() {
  case "$OFFICE_BACKEND" in
    gotenberg)
      command::exists curl || log::fatal "curl not found (needed for the gotenberg backend)"
      office::gotenberg_reachable || log::fatal "Gotenberg not reachable at ${GOT_URL}"
      ;;
    libreoffice)
      command::exists soffice || log::fatal "soffice (LibreOffice) not found"
      ;;
    auto)
      if command::exists curl && office::gotenberg_reachable; then
        OFFICE_BACKEND="gotenberg"
      elif command::exists soffice; then
        OFFICE_BACKEND="libreoffice"
      else
        log::fatal "no backend available: Gotenberg unreachable (${GOT_URL}) and soffice not installed"
      fi
      ;;
    *) log::fatal "Unknown backend: ${OFFICE_BACKEND} (use auto|gotenberg|libreoffice)" ;;
  esac

  if [[ $OFFICE_BACKEND == "libreoffice" && -n $OFFICE_PDFA ]]; then
    log::warn "PDF/A is only produced by the gotenberg backend; LibreOffice fallback emits plain PDF"
    OFFICE_PDFA=""
  fi

  log::info "backend: ${OFFICE_BACKEND}${OFFICE_PDFA:+ (PDF/A)}"
}

# Map an extension to its LibreOffice PDF export filter; non-zero if unsupported.
office::lo_filter() {
  case "${1,,}" in
    *.doc | *.docx | *.docm | *.dot | *.dotx | *.dotm | *.rtf | *.odt | *.ott) printf 'writer_pdf_Export' ;;
    *.xls | *.xlsx | *.xlsm | *.xlt | *.xltx | *.xltm | *.ods | *.csv | *.ots) printf 'calc_pdf_Export' ;;
    *.ppt | *.pptx | *.pptm | *.pps | *.ppsx | *.pot | *.potx | *.potm | *.odp | *.otp) printf 'impress_pdf_Export' ;;
    *) return 1 ;;
  esac
}

office::add_dir() {
  local dir="$1" maxdepth=(-maxdepth 1) f
  [[ $OFFICE_RECURSIVE == 1 ]] && maxdepth=()
  while IFS= read -r -d '' f; do
    OFFICE_FILES+=("$f")
  done < <(find "$dir" "${maxdepth[@]}" \
    -type d -name original_ms_files -prune -o \
    -type f \( "${OFFICE_NAME_TESTS[@]}" \) -print0)
}

office::collect() {
  [[ ${#OFFICE_POS[@]} -gt 0 ]] || OFFICE_POS=(".")

  local e
  for e in "${OFFICE_EXTS[@]}"; do
    OFFICE_NAME_TESTS+=(-iname "*.$e" -o)
  done
  unset 'OFFICE_NAME_TESTS[${#OFFICE_NAME_TESTS[@]}-1]'

  local p
  for p in "${OFFICE_POS[@]}"; do
    if [[ -f $p ]]; then
      OFFICE_FILES+=("$p")
    elif [[ -d $p ]]; then
      office::add_dir "$p"
    else
      log::warn "skipping (not a file or directory): $p"
    fi
  done

  [[ ${#OFFICE_FILES[@]} -gt 0 ]] || {
    log::info "No convertible documents found"
    exit 0
  }

  # Count how many sources map to each output stem, so colliding base names
  # (deck.odp + deck.pptx) can be disambiguated instead of overwriting/skipping.
  local f k
  for f in "${OFFICE_FILES[@]}"; do
    k="${f%.*}"
    OFFICE_STEM_COUNT["$k"]=$((${OFFICE_STEM_COUNT["$k"]:-0} + 1))
  done
}

office::_via_gotenberg() {
  local src="$1" out="$2"
  local args=(--fail --silent --show-error --connect-timeout 10 --max-time 300
    --request POST "${GOT_URL}/forms/libreoffice/convert"
    --form "files=@${src}")
  [[ -n $OFFICE_PDFA ]] && args+=(--form "pdfa=${OFFICE_PDFA}")
  args+=(-o "$out")
  curl "${args[@]}"
}

office::_via_libreoffice() {
  local src="$1" out="$2" filter outdir="."
  filter=$(office::lo_filter "$src") || {
    log::error "unsupported by LibreOffice filter: $src"
    return 1
  }
  [[ $out == */* ]] && outdir="${out%/*}"

  # Private profile dir so headless conversion works even with a GUI LO open.
  soffice --headless --nologo --norestore --nolockcheck --nodefault --nofirststartwizard \
    "-env:UserInstallation=file:///tmp/lo-$(id -u)-office2pdf" \
    --convert-to "pdf:$filter" --outdir "$outdir" "$src" > /dev/null 2>&1 || return 1
  return 0
}

office::convert_one() {
  local src="$1"
  local stem="${src%.*}" out
  # On a base-name clash keep the source extension (deck.pptx.pdf); otherwise
  # use the clean name (deck.pdf). Deterministic and idempotent on re-runs.
  if ((${OFFICE_STEM_COUNT["$stem"]:-1} > 1)); then
    out="${src}.pdf"
  else
    out="${stem}.pdf"
  fi
  local dir="."
  [[ $src == */* ]] && dir="${src%/*}"
  local orig_dir="$dir/original_ms_files"

  if [[ -e $out && $OFFICE_FORCE != 1 ]]; then
    log::info "skip (exists, use --force): $out"
    OFFICE_SKIPPED=$((OFFICE_SKIPPED + 1))
    return 0
  fi

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${OFFICE_BACKEND}: $src -> $out${OFFICE_PDFA:+ (PDF/A)}, move original into $orig_dir/"
    OFFICE_ORIG_DIRS["$orig_dir"]=1
    return 0
  fi

  log::info "converting: $src -> $out"
  local ok=0
  case "$OFFICE_BACKEND" in
    gotenberg) office::_via_gotenberg "$src" "$out" && ok=1 ;;
    libreoffice) office::_via_libreoffice "$src" "$out" && ok=1 ;;
  esac

  if [[ $ok == 1 ]]; then
    mkdir -p -- "$orig_dir"
    file::move "$src" "$orig_dir/${src##*/}"
    OFFICE_ORIG_DIRS["$orig_dir"]=1
    OFFICE_CONVERTED=$((OFFICE_CONVERTED + 1))
  else
    log::error "conversion failed: $src"
    [[ -s $out ]] || rm -f -- "$out"
    OFFICE_FAILED=$((OFFICE_FAILED + 1))
  fi
}

office::convert_all() {
  local src
  for src in "${OFFICE_FILES[@]}"; do
    office::convert_one "$src"
  done
}

office::archive_one() {
  local dir="$1" parent="${1%/*}" archive n=1
  archive="$parent/original_ms_files.tar.xz"
  while [[ -e $archive ]]; do
    archive="$parent/original_ms_files-${n}.tar.xz"
    n=$((n + 1))
  done

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] archive $dir -> $archive"
    return 0
  fi

  if tar -C "$parent" -cJf "$archive" original_ms_files; then
    log::info "archived: $archive"
    rm -rf -- "$dir"
  else
    log::error "tar failed for: $dir"
  fi
}

office::archive_originals() {
  local d
  for d in "${!OFFICE_ORIG_DIRS[@]}"; do
    office::archive_one "$d"
  done
}

office::summary() {
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    log::info "[dry-run] ${#OFFICE_FILES[@]} document(s) considered"
    return 0
  fi
  log::info "Done: ${OFFICE_CONVERTED} converted, ${OFFICE_SKIPPED} skipped, ${OFFICE_FAILED} failed"
}

main() {
  banner::print "office2pdf"
  office::parse_args "$@"
  office::require_deps
  office::select_backend
  office::collect
  office::convert_all
  office::archive_originals
  office::summary
}

main "$@"
