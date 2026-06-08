#!/usr/bin/env bash
#
#                ______
#     ____  ____/ / __/
#    / __ \/ __  / /_
#   / /_/ / /_/ / __/
#  / .___/\__,_/_/
# /_/
#
# PDF validators and processors built on qpdf, exiftool, and Ghostscript.

pdf::is_real_pdf() {
  local f="${1:?pdf::is_real_pdf requires a path}"
  [[ -f $f && -s $f ]] || {
    log::error "missing or empty: $f"
    return 1
  }

  local mime
  mime=$(file --mime-type -b -- "$f" 2> /dev/null)
  case "$mime" in
    application/pdf) ;;
    *) log::warn "unexpected MIME ($mime), continuing -- qpdf will decide" ;;
  esac

  qpdf --warning-exit-0 --check -- "$f" > /dev/null 2>&1 \
    || {
      log::error "qpdf cannot parse: $f"
      return 1
    }
}

# Validates a PDF. If corrupt, moves it to a 'BAD_PDF' folder.
pdf::validate() {
  local f="${1:?file required}"
  if pdf::is_real_pdf "$f"; then
    return 0
  else
    log::warn "PDF corrupt or invalid: $f"
    dir::create "BAD_PDF"
    file::move "$f" "BAD_PDF/$(basename -- "$f")"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# In-place processing with rollback (mirrors lib/image.sh).
#
# pdf-compress and pdf-sanitize both REPLACE the file in place and keep the
# original under ORIGINAL_PDF/, mirroring the source path (relative to cwd when
# inside it, else its absolute path minus the leading slash) so same-named files
# in different directories never collide. The archived copy doubles as an
# idempotency marker: a file whose original is already archived is skipped, so
# re-running over a tree is a safe no-op.
# -----------------------------------------------------------------------------

# Echo where INPUT's original is (or would be) archived under ROOT.
pdf::archive_dest() {
  local root="${1:?pdf::archive_dest requires ROOT}" input="${2:?pdf::archive_dest requires INPUT}"
  local abs cwd rel
  abs="$(readlink -f -- "$input")"
  cwd="$(pwd -P)"
  if [[ $abs == "$cwd"/* ]]; then
    rel="${abs#"$cwd"/}"
  else
    rel="${abs#/}"
  fi
  printf '%s/%s' "$root" "$rel"
}

# Per-tool completion stamp: <archived-original>.<TAG>. Each tool records its own
# stamp, so several tools can each process a file once (e.g. sanitize -> compress
# chains work) while a single TRUE original is kept under ROOT/<rel>.
pdf::stamp_path() {
  printf '%s.%s' "$(pdf::archive_dest "${1:?ROOT}" "${2:?INPUT}")" "${3:?TAG}"
}

# True when the TAG tool already processed INPUT (its stamp exists) -- skip signal.
pdf::already_processed() {
  [[ -e "$(pdf::stamp_path "${1:?ROOT}" "${2:?INPUT}" "${3:?TAG}")" ]]
}

# Commit a processed result in place: archive the TRUE original under ROOT (path-
# mirrored, for rollback) -- only the first tool to touch a file archives it, so
# later tools in a chain keep the earliest original -- then replace INPUT with TMP
# and drop the per-tool TAG stamp. INPUT is left untouched on any failure.
pdf::commit_in_place() {
  local root="${1:?pdf::commit_in_place requires ROOT}" input="${2:?requires INPUT}"
  local tmp="${3:?requires TMP}" tag="${4:?requires TAG}"
  local dest stamp
  dest="$(pdf::archive_dest "$root" "$input")"
  stamp="$(pdf::stamp_path "$root" "$input" "$tag")"
  dir::create "$(dirname -- "$dest")" || return 1
  if [[ ! -e $dest ]]; then
    file::copy "$input" "$dest" || {
      log::error "could not archive original (aborting, file untouched): $input"
      return 1
    }
  fi
  # The archived copy is the rollback, so overwrite in place with no backup
  # (input still exists here; --backup would leave a stray <name>.~1~).
  mv -f -- "$tmp" "$input" || {
    log::error "could not replace in place: $input"
    return 1
  }
  : > "$stamp" # record that the TAG tool ran on this file
}

pdf::remove_metadata() {
  local input="${1:?pdf::remove_metadata requires INPUT}" output="${2:?pdf::remove_metadata requires OUTPUT}"
  os::check_dependency qpdf exiftool file || return 1
  file::is_regular "$input" || return 1
  pdf::is_real_pdf "$input" || return 1

  # Work on a COPY so INPUT is never mutated (exiftool -overwrite_original would
  # otherwise strip the source in place) -- keeps this a clean input->output op,
  # so callers can safely archive the untouched original.
  local work intermediate
  work=$(mktemp --tmpdir "pdf-meta-XXXXXX.pdf") || return 1
  intermediate=$(mktemp --tmpdir "pdf-clean-XXXXXX.pdf") || {
    rm -f -- "$work"
    return 1
  }
  cp -- "$input" "$work" || {
    rm -f -- "$work" "$intermediate"
    return 1
  }

  # exiftool clears the document Info dict and XMP packet; the qpdf rebuild then
  # drops orphaned objects that can still hold those tags. Metadata embedded
  # *inside* page images (e.g. EXIF in an embedded JPEG XObject) is NOT reached
  # by this -- use pdf::sanitize with paranoid=1 (rasterize) to guarantee that.
  exiftool -all= -overwrite_original -P "$work" || {
    rm -f -- "$work" "$intermediate"
    return 1
  }

  if ! qpdf --empty --pages "$work" 1-z -- "$intermediate"; then
    log::error "qpdf page rebuild failed: $input"
    rm -f -- "$work" "$intermediate"
    return 1
  fi
  if ! qpdf --object-streams=disable --deterministic-id --linearize "$intermediate" "$output"; then
    log::error "qpdf linearize failed: $input"
    rm -f -- "$work" "$intermediate" "$output"
    return 1
  fi
  rm -f -- "$work" "$intermediate"
  log::info "metadata removed: $output"
}

pdf::compress() {
  local input="${1:?pdf::compress requires INPUT}" output="${2:?pdf::compress requires OUTPUT}" quality="${3:?pdf::compress requires QUALITY 1..4}"
  os::check_dependency gs || return 1
  file::is_regular "$input" || return 1
  pdf::is_real_pdf "$input" || return 1

  local setting
  case "$quality" in
    1) setting=/screen ;;
    2) setting=/ebook ;;
    3) setting=/printer ;;
    4) setting=/prepress ;;
    *)
      log::error "quality must be 1..4 (got '$quality')"
      return 1
      ;;
  esac
  log::info "compressing PDF (${setting}): $input -> $output"

  if gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS="$setting" \
    -dRemoveUnusedResources=true -dCompressFonts=true -dSubsetFonts=true \
    -dEmbedAllFonts=true -dNumRenderingThreads=4 -dNOTRANSPARENCY \
    -dNOPAUSE -dQUIET -dBATCH -dSAFER \
    -sOutputFile="$output" "$input"; then
    log::info "compressed: $output"
  else
    log::error "compress failed"
    rm -f -- "$output"
    return 1
  fi
}

pdf::merge() {
  local output="${1:?pdf::merge requires OUTPUT}"
  shift
  (($# >= 2)) || {
    log::error "pdf::merge requires at least 2 input PDFs"
    return 1
  }
  os::check_dependency gs || return 1

  local f
  for f in "$@"; do
    file::is_regular "$f" || return 1
    pdf::is_real_pdf "$f" || return 1
  done
  output=$(string::next_available_path "$output")

  log::info "merging $# files -> $output"
  if gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook \
    -dRemoveUnusedResources=true -dPDFSTOPONERROR -dNumRenderingThreads=4 \
    -dEmbedAllFonts=true -dSubsetFonts=true -dCompressFonts=true \
    -dDetectDuplicateImages=true -dNOTRANSPARENCY -dAutoRotatePages=/None \
    -dNOPAUSE -dBATCH -dQUIET -dSAFER \
    -sOutputFile="$output" -f "$@"; then
    log::info "merged: $output"
  else
    log::error "merge failed"
    rm -f -- "$output"
    return 1
  fi
}

pdf::to_bw() {
  local input="${1:?pdf::to_bw requires INPUT}" output="${2:?pdf::to_bw requires OUTPUT}"
  os::check_dependency gs || return 1
  file::is_regular "$input" || return 1
  pdf::is_real_pdf "$input" || return 1

  log::info "converting to black and white: $input -> $output"

  if gs -sOutputFile="$output" \
    -sDEVICE=pdfwrite \
    -sColorConversionStrategy=Gray \
    -dProcessColorModel=/DeviceGray \
    -dCompatibilityLevel=1.4 \
    -dNOPAUSE -dBATCH -dQUIET -dSAFER \
    "$input"; then
    log::info "converted to B&W: $output"
  else
    log::error "B&W conversion failed"
    rm -f -- "$output"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Sanitization -- make an untrusted PDF safe to open and share.
#
# pdf::sanitize is the orchestrator (scan -> defang -> strip metadata -> optional
# OCR -> linearize). The two defang strategies below are the security core:
#
#   structural (default) -- Ghostscript re-distills the PDF (pdfwrite rebuilds it
#       from page content, so document JavaScript, /OpenAction, /Launch actions,
#       /Names trees and /EmbeddedFiles do not survive); selectable text is kept.
#   paranoid              -- every page is rendered to a raster image and a fresh
#       PDF is built from those images. Nothing from the original byte-stream
#       survives, neutralizing polyglots and metadata embedded inside page
#       images too -- at the cost of text selectability and file size.
# -----------------------------------------------------------------------------

# ClamAV signature scan. Prefers clamdscan (talks to the resident clamav-daemon,
# which keeps the ~600MB signature DB loaded and freshclam-updated -- instant,
# vs ~12s of DB load per file with clamscan); falls back to clamscan if the
# daemon is unavailable. Returns 1 only when a known infection is found (and
# quarantines the file); a missing scanner or scan error is non-fatal so the
# defang step still runs. Mirrors video::_clamav_scan.
pdf::_clamav_scan() {
  local f="${1:?pdf::_clamav_scan requires a file}"

  local scanner=""
  if command::exists clamdscan; then
    scanner="clamdscan"
  elif command::exists clamscan; then
    scanner="clamscan"
  else
    log::warn "no ClamAV scanner -- skipping signature scan (install the 'security' package group)"
    return 0
  fi

  log::info "ClamAV (${scanner}) scanning: $f ..."
  local rc=0
  if [[ $scanner == clamdscan ]]; then
    clamdscan --fdpass --no-summary --infected -- "$f" || rc=$?
    # rc 2 = daemon unreachable/error -> fall back to the standalone scanner.
    if [[ $rc -eq 2 ]] && command::exists clamscan; then
      log::warn "clamd unavailable -- falling back to clamscan (slower)"
      rc=0
      clamscan --no-summary --infected -- "$f" || rc=$?
    fi
  else
    clamscan --no-summary --infected -- "$f" || rc=$?
  fi

  case "$rc" in
    0) return 0 ;;
    1)
      log::error "MALWARE DETECTED by ClamAV: $f"
      dir::create QUARANTINE
      file::move "$f" "QUARANTINE/$(basename -- "$f")"
      return 1
      ;;
    *) log::warn "ClamAV error (rc=$rc) -- continuing with defang sanitization" ;;
  esac
}

# Structural defang: re-distill via Ghostscript so active content is dropped,
# then strip metadata and linearize. Keeps selectable text.
pdf::_defang_structural() {
  local input="${1:?pdf::_defang_structural requires INPUT}" output="${2:?pdf::_defang_structural requires OUTPUT}"
  os::check_dependency gs qpdf exiftool || return 1

  local rebuilt
  rebuilt=$(mktemp --tmpdir "pdf-defang-XXXXXX.pdf") || return 1

  # -dPreserveAnnots=false drops every annotation, which is where the remaining
  # annotation-borne vectors live (Link /URI phishing, Screen/Widget /AA scripts,
  # Movie/Sound/RichMedia/3D). gs already omits document JavaScript, /OpenAction
  # and /Launch; the qpdf --empty --pages rebuild in pdf::remove_metadata then
  # discards the catalog /Names tree (named JavaScript + /EmbeddedFiles). The
  # cost is that legitimate hyperlinks and form fields are lost -- acceptable for
  # a safety-first default; document bookmarks (/Outlines) survive.
  if ! gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.7 -dPDFSETTINGS=/prepress \
    -dPreserveAnnots=false -dDetectDuplicateImages=true \
    -dCompressFonts=true -dSubsetFonts=true \
    -dNOPAUSE -dBATCH -dQUIET -dSAFER \
    -sOutputFile="$rebuilt" -- "$input"; then
    log::error "structural defang (Ghostscript) failed: $input"
    rm -f -- "$rebuilt"
    return 1
  fi

  if ! pdf::remove_metadata "$rebuilt" "$output"; then
    rm -f -- "$rebuilt"
    return 1
  fi
  rm -f -- "$rebuilt"
}

# Paranoid defang: render each page to a raster image, then rebuild a PDF from
# those images. img2pdf is preferred (lossless, no metadata, correct page size);
# ImageMagick 'convert' is the fallback. Loses selectable text by design.
pdf::_defang_paranoid() {
  local input="${1:?pdf::_defang_paranoid requires INPUT}" output="${2:?pdf::_defang_paranoid requires OUTPUT}"
  local dpi="${3:-200}"
  os::check_dependency pdftoppm || return 1

  local workdir
  workdir=$(mktemp -d --tmpdir "pdf-raster-XXXXXX") || return 1

  if ! pdftoppm -png -r "$dpi" -- "$input" "$workdir/pg"; then
    log::error "paranoid defang: page rasterization failed: $input"
    rm -rf -- "$workdir"
    return 1
  fi

  local -a pages=()
  local p
  while IFS= read -r -d '' p; do pages+=("$p"); done \
    < <(find "$workdir" -maxdepth 1 -type f -name 'pg*.png' -print0 | sort -z)
  if [[ ${#pages[@]} -eq 0 ]]; then
    log::error "paranoid defang: no pages rendered: $input"
    rm -rf -- "$workdir"
    return 1
  fi

  local rc=0
  if command::exists img2pdf; then
    img2pdf --output "$output" -- "${pages[@]}" || rc=$?
  elif command::exists convert; then
    log::warn "img2pdf not found -- falling back to ImageMagick (may be blocked by its PDF policy)"
    convert "${pages[@]}" -- "$output" || rc=$?
  else
    log::error "paranoid defang needs img2pdf (preferred) or ImageMagick 'convert'"
    rc=1
  fi

  rm -rf -- "$workdir"
  if [[ $rc -ne 0 ]]; then
    log::error "paranoid defang: PDF rebuild failed: $input"
    rm -f -- "$output"
    return 1
  fi
}

# Add a searchable text layer in place. --skip-text leaves pages that already
# carry text untouched, so it is safe on both structural (has text) and paranoid
# (image-only) output, and idempotent on re-runs. --output-type pdf avoids
# ocrmypdf's PDF/A step, whose Ghostscript driver breaks across some
# ocrmypdf/Ghostscript version pairs ("rangecheck in .putdeviceprops"); a plain
# searchable PDF is all sanitize needs.
pdf::_ocr() {
  local file="${1:?pdf::_ocr requires a file}"
  command::exists ocrmypdf || {
    log::warn "ocrmypdf not installed -- skipping OCR text layer (install the 'docs' package group)"
    return 0
  }
  if ocrmypdf --skip-text --optimize 0 --output-type pdf --quiet -- "$file" "$file"; then
    log::info "OCR text layer added: $file"
  else
    log::warn "OCR failed -- leaving $file without a text layer"
  fi
}

# Print the count of risk-bearing pdfid keywords for a file, one "N /Keyword"
# line per non-zero hit, and echo the grand total on the last line. Used by
# pdf::sanitize --report to *prove* the defang dropped active content to zero,
# rather than asserting it. pdfid only parses structure (it never executes the
# PDF), so running it on an untrusted input is safe.
pdf::_pdfid_counts() {
  local f="${1:?pdf::_pdfid_counts requires a file}"
  pdfid "$f" 2> /dev/null | awk '
    $1 ~ /^\/(JS|JavaScript|AA|OpenAction|Launch|EmbeddedFile|URI|AcroForm|RichMedia|JBIG2Decode|XFA|Encrypt|ObjStm)$/ {
      if (($2 + 0) > 0) { printf "    %d %s\n", $2, $1; total += $2 }
    }
    END { printf "TOTAL %d\n", total + 0 }'
}

# Defense-in-depth signature scan with YARA against the COMPILED ruleset at
# DOTFILES_YARA_RULES (a .yarc built by the yara-rules task, default under the
# data dir). A match quarantines the file; a missing engine or ruleset is
# non-fatal (the defang still neutralizes unknown threats). Mirrors
# pdf::_clamav_scan.
pdf::_yara_scan() {
  local f="${1:?pdf::_yara_scan requires a file}"
  command::exists yara || return 0
  local rules="${DOTFILES_YARA_RULES:?DOTFILES_YARA_RULES must be set in local/env.sh}"
  [[ -s $rules ]] || {
    log::warn "YARA installed but no compiled ruleset at $rules -- run the 'yara-rules' task; skipping YARA scan"
    return 0
  }

  # signature-base rules reference these external variables; supply real values
  # so filename/extension-based rules evaluate correctly (declared at compile
  # time by the yara-rules task). -C loads the compiled ruleset; yara does not
  # accept a `--` separator, so paths are passed directly.
  local base ext
  base=$(basename -- "$f")
  ext=".${f##*.}"
  ext="${ext,,}"
  local -a ext_vars=(-d filename="$base" -d filepath="$f" -d extension="$ext" -d filetype="" -d owner="")

  log::info "YARA scanning: $f ..."
  local hits
  hits=$(yara -C -w "${ext_vars[@]}" "$rules" "$f" 2> /dev/null) || {
    log::warn "yara error scanning $f -- skipping (defang still runs)"
    return 0
  }
  if [[ -n $hits ]]; then
    log::error "YARA RULE MATCH on $f: $(printf '%s' "$hits" | awk '{print $1}' | paste -sd, -)"
    dir::create QUARANTINE
    file::move "$f" "QUARANTINE/$(basename -- "$f")"
    return 1
  fi
}

# Independent-parser validation of a produced file. pdfcpu is a clean-room Go
# parser (not Ghostscript/qpdf/poppler), so passing its validation is real
# defense-in-depth that the sanitized output is well-formed. Non-fatal if pdfcpu
# is not installed; a relaxed-mode failure is a hard error (reject the output).
pdf::_pdfcpu_validate() {
  local f="${1:?pdf::_pdfcpu_validate requires a file}"
  command::exists pdfcpu || return 0
  if pdfcpu validate -m relaxed "$f" > /dev/null 2>&1; then
    log::info "pdfcpu validation passed: $f"
  else
    log::error "pdfcpu (independent parser) rejected the output: $f"
    return 1
  fi
}

# Make an untrusted PDF safe. Pipeline: ClamAV + YARA detection gates (quarantine
# before any rewrite) -> defang (structural or paranoid) -> optional OCR -> validity
# + pdfcpu independent-parser check -> quarantine original. Reads optional overrides
# (mirrors the video::sanitize env-var convention):
#   DOTFILES_PDF_SANITIZE_PARANOID  0 (structural, default) | 1 (rasterize)
#   DOTFILES_PDF_SANITIZE_OCR       0 (default) | 1 (add a searchable text layer)
#   DOTFILES_PDF_SANITIZE_DPI       rasterization DPI for paranoid mode (default 200)
#   DOTFILES_PDF_SANITIZE_REPORT    0 (default) | 1 (pdfid before/after verification)
# Clean copies land in CLEAN/; the original is moved to QUARANTINE/.
pdf::sanitize() {
  local input="${1:?pdf::sanitize requires a file}"
  file::is_readable "$input" || return 1

  # Idempotency: skip if THIS tool already sanitized the file (its stamp exists);
  # a compress/metadata stamp from another tool does not block sanitizing.
  if pdf::already_processed ORIGINAL_PDF "$input" sanitized; then
    log::info "already sanitized: $input"
    return 0
  fi

  local paranoid="${DOTFILES_PDF_SANITIZE_PARANOID:-}"
  local ocr="${DOTFILES_PDF_SANITIZE_OCR:-}"
  local dpi="${DOTFILES_PDF_SANITIZE_DPI:?DOTFILES_PDF_SANITIZE_DPI must be set in local/env.sh}"
  local report="${DOTFILES_PDF_SANITIZE_REPORT:-}"

  # Detection gates: known-signature scans that quarantine before any rewrite.
  pdf::_clamav_scan "$input" || return 1
  pdf::_yara_scan "$input" || return 1
  if ! pdf::is_real_pdf "$input"; then
    log::warn "not a valid PDF -- moving to BAD_PDF: $input"
    dir::create BAD_PDF
    file::move "$input" "BAD_PDF/$(basename -- "$input")"
    return 1
  fi

  if [[ $report == 1 ]] && command::exists pdfid; then
    log::info "pdfid (before) -- risk keywords in $input:"
    pdf::_pdfid_counts "$input" | sed '$d'
  fi

  # Defang to a temp file; on success the original is archived under ORIGINAL_PDF/
  # (path-mirrored) and the cleaned file replaces it in place. A scanner-flagged
  # file never reaches here -- it was already moved to QUARANTINE/.
  local output
  output=$(mktemp --tmpdir "pdf-clean-XXXXXX.pdf") || return 1

  if [[ $paranoid == 1 ]]; then
    log::info "sanitizing in place (paranoid: rasterize @ ${dpi}dpi): $input"
    pdf::_defang_paranoid "$input" "$output" "$dpi" || {
      rm -f -- "$output"
      return 1
    }
  else
    log::info "sanitizing in place (structural: re-distill + strip): $input"
    pdf::_defang_structural "$input" "$output" || {
      rm -f -- "$output"
      return 1
    }
  fi

  [[ $ocr == 1 ]] && pdf::_ocr "$output"

  if ! pdf::is_real_pdf "$output"; then
    log::error "sanitize produced an invalid PDF: $input"
    rm -f -- "$output"
    return 1
  fi
  pdf::_pdfcpu_validate "$output" || {
    rm -f -- "$output"
    return 1
  }

  if [[ $report == 1 ]] && command::exists pdfid; then
    local after total
    after=$(pdf::_pdfid_counts "$output")
    total=$(printf '%s' "$after" | awk '/^TOTAL/ {print $2}')
    log::info "pdfid (after) -- risk keywords in the cleaned file:"
    printf '%s' "$after" | sed '$d'
    if [[ ${total:-0} -eq 0 ]]; then
      log::info "verification: 0 risk keywords remain ✔"
    else
      log::warn "verification: ${total} risk keyword(s) still present (expected for some structural cases, e.g. /ObjStm)"
    fi
  fi

  if ! pdf::commit_in_place ORIGINAL_PDF "$input" "$output" sanitized; then
    rm -f -- "$output"
    return 1
  fi
  log::info "sanitized in place: $input (original archived -> $(pdf::archive_dest ORIGINAL_PDF "$input"))"
}
