#!/usr/bin/env bash
# Helpers for document conversion and processing.

docs::md_to_pdf() {
  local in="${1:?docs::md_to_pdf requires an input file}"
  local out="${2:?docs::md_to_pdf requires an output file}"
  shift 2
  local extra_args=("$@")

  if ! command -v pandoc &> /dev/null; then
    log::error "pandoc not found. Please install the docs package group."
    return 1
  fi

  log::info "Converting $in to $out..."

  if pandoc "$in" -o "$out" \
    --pdf-engine=xelatex \
    -V mainfont="DejaVu Sans" \
    "${extra_args[@]}"; then
    log::info "Successfully generated $out"
  else
    log::error "Failed to generate PDF from $in"
    return 1
  fi
}

docs::md_to_html() {
  local in="${1:?docs::md_to_html requires an input file}"
  local out="${2:?docs::md_to_html requires an output file}"

  if ! command -v pandoc &> /dev/null; then
    log::error "pandoc not found."
    return 1
  fi

  log::info "Converting $in to $out..."
  if pandoc "$in" -s --self-contained -o "$out"; then
    log::info "Successfully generated $out"
  else
    log::error "Failed to generate HTML from $in"
    return 1
  fi
}
