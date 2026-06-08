#!/usr/bin/env bash
# Project-type detection, tag-based exclusion composition, and tree-walking.
# Shared by archive-* and clean-all-* scripts so detection rules and
# exclusion sets live in one place.
#
# Detector contract: project::is_<tag> <dir> returns 0 if <dir> exhibits
# that signal. Detectors look at the root only -- recursion is the
# walker's job (project::for_each_matching).
#
# Exclusion philosophy (read before adding entries):
#   - Exclude only GENERATED / CACHE / BUILD output.
#   - Never exclude source files, lockfiles, Dockerfile, .env*, README,
#     LICENSE, package.json, pom.xml, etc. -- these are user-authored
#     and removing them silently destroys reproducibility.
#   - Never exclude .git/ -- history is precious, ship it.
#   - Never exclude .idea/ or .vscode/ by default -- many teams commit
#     shared IDE config. (Users can `find . -name .idea -delete` first
#     if they want them gone.)
#   - When the same artifact has two names across stacks (e.g. "target"
#     for both Maven and Rust), it's fine -- they only get unioned if
#     the corresponding tag is detected.

# Framework priority for project::auto_detect (most-specific first).
# An Ionic project also matches Angular, so ionic must be tried first.
PROJECT_TYPES_PRIORITY=(ionic flutter angular java dotnet latex)

# Every tag with a project::is_<tag> detector. Used by project::detect_tags
# to enumerate which signals a directory exhibits. Framework tags first,
# tooling tags second -- order is purely cosmetic for the tag listing.
PROJECT_TAGS_ALL=(
  angular ionic flutter java dotnet latex
  maven gradle node python rust
  webpack vite nextjs nuxt cocoapods
)

# ---------------------------------------------------------------------------
# Framework detectors
# ---------------------------------------------------------------------------

project::is_angular() {
  local dir="${1:?project::is_angular requires DIR}"
  [[ -f "${dir}/angular.json" && -f "${dir}/package.json" ]] \
    && grep -q '"@angular/core"' "${dir}/package.json"
}

# A Dart-only package also has pubspec.yaml -- require the `flutter:` SDK
# key to distinguish a Flutter app from a plain Dart library.
project::is_flutter() {
  local dir="${1:?project::is_flutter requires DIR}"
  [[ -f "${dir}/pubspec.yaml" ]] \
    && grep -Eq '^[[:space:]]*flutter:[[:space:]]*$' "${dir}/pubspec.yaml"
}

project::is_ionic() {
  local dir="${1:?project::is_ionic requires DIR}"
  [[ -f "${dir}/ionic.config.json" ]]
}

project::is_java() {
  local dir="${1:?project::is_java requires DIR}"
  project::is_maven "$dir" || project::is_gradle "$dir"
}

project::is_dotnet() {
  local dir="${1:?project::is_dotnet requires DIR}"
  compgen -G "${dir}/*.csproj" > /dev/null \
    || compgen -G "${dir}/*.fsproj" > /dev/null \
    || compgen -G "${dir}/*.sln" > /dev/null
}

# LaTeX has no marker file -- accept any directory containing a .tex.
project::is_latex() {
  local dir="${1:?project::is_latex requires DIR}"
  compgen -G "${dir}/*.tex" > /dev/null
}

# ---------------------------------------------------------------------------
# Build-system / tooling detectors (composable signals)
# ---------------------------------------------------------------------------

project::is_maven() {
  local dir="${1:?project::is_maven requires DIR}"
  [[ -f "${dir}/pom.xml" ]]
}

project::is_gradle() {
  local dir="${1:?project::is_gradle requires DIR}"
  [[ -f "${dir}/build.gradle" ||
    -f "${dir}/build.gradle.kts" ||
    -f "${dir}/settings.gradle" ||
    -f "${dir}/settings.gradle.kts" ]]
}

# Shallow-glob: also matches embedded frontends one level down
# (e.g. Spring Boot with frontend/package.json). Goes one level only --
# anything deeper is the user's job to point us at directly.
project::is_node() {
  local dir="${1:?project::is_node requires DIR}"
  [[ -f "${dir}/package.json" ]] \
    || compgen -G "${dir}/*/package.json" > /dev/null
}

project::is_python() {
  local dir="${1:?project::is_python requires DIR}"
  [[ -f "${dir}/pyproject.toml" ||
    -f "${dir}/setup.py" ||
    -f "${dir}/setup.cfg" ||
    -f "${dir}/requirements.txt" ||
    -f "${dir}/Pipfile" ||
    -d "${dir}/.venv" ||
    -d "${dir}/venv" ]]
}

project::is_rust() {
  local dir="${1:?project::is_rust requires DIR}"
  [[ -f "${dir}/Cargo.toml" ]]
}

# JS-ecosystem detectors also shallow-glob -- see project::is_node note.

project::is_webpack() {
  local dir="${1:?project::is_webpack requires DIR}"
  local f
  for f in webpack.config.js webpack.config.ts webpack.config.mjs; do
    [[ -f "${dir}/${f}" ]] && return 0
    compgen -G "${dir}/*/${f}" > /dev/null && return 0
  done
  [[ -d "${dir}/.webpack-cache" ]]
}

project::is_vite() {
  local dir="${1:?project::is_vite requires DIR}"
  local f
  for f in vite.config.js vite.config.ts vite.config.mjs; do
    [[ -f "${dir}/${f}" ]] && return 0
    compgen -G "${dir}/*/${f}" > /dev/null && return 0
  done
  [[ -d "${dir}/.vite" ]]
}

project::is_nextjs() {
  local dir="${1:?project::is_nextjs requires DIR}"
  local f
  for f in next.config.js next.config.mjs next.config.ts; do
    [[ -f "${dir}/${f}" ]] && return 0
    compgen -G "${dir}/*/${f}" > /dev/null && return 0
  done
  [[ -d "${dir}/.next" ]]
}

project::is_nuxt() {
  local dir="${1:?project::is_nuxt requires DIR}"
  local f
  for f in nuxt.config.js nuxt.config.ts; do
    [[ -f "${dir}/${f}" ]] && return 0
    compgen -G "${dir}/*/${f}" > /dev/null && return 0
  done
  [[ -d "${dir}/.nuxt" ]]
}

project::is_cocoapods() {
  local dir="${1:?project::is_cocoapods requires DIR}"
  [[ -f "${dir}/Podfile" || -f "${dir}/ios/Podfile" ]]
}

# A permissive detector for callers that want "any directory".
project::is_any() {
  [[ -d "${1:-}" ]]
}

# True when <dir> matches any framework type (not just any tag). Lets
# archive-auto's --recursive walk skip dirs that aren't a real project.
project::is_any_recognized() {
  project::auto_detect "${1:-}" > /dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Per-tag exclusion arrays
#
# Naming: PROJECT_EXCLUDES_<TAG_UPPERCASE>. Looked up dynamically by
# project::union_excludes. Add a new tag = add the detector + the array.
# ---------------------------------------------------------------------------

# Always merged into every union. OS junk + transient state only.
readonly PROJECT_EXCLUDES_COMMON=(
  .DS_Store Thumbs.db '*.log' '*.pid'
  '*.swp' '*.swo' '*~'
)

# Framework-level exclusions (generated/cache state; build-system stuff
# is in MAVEN/GRADLE/NODE so a Spring Boot + Webpack project unions them).
readonly PROJECT_EXCLUDES_ANGULAR=(
  .angular .angular/cache out-tsc
  cypress/screenshots cypress/videos storybook-static
  .nx .nx/cache .sass-cache .eslintcache
  coverage
)

readonly PROJECT_EXCLUDES_IONIC=(
  platforms plugins www .capacitor
)

readonly PROJECT_EXCLUDES_FLUTTER=(
  .dart_tool .flutter-plugins
  .flutter-plugins-dependencies .metadata .fvm/flutter_sdk
  android/.gradle android/.cxx android/build android/app/build
  ios/Pods ios/.symlinks ios/Flutter ios/build ios/DerivedData
  macos/Pods macos/Flutter/ephemeral macos/build
  windows/flutter/ephemeral windows/build
  linux/flutter/ephemeral linux/build
)

readonly PROJECT_EXCLUDES_JAVA=(
  .scannerwork
)

readonly PROJECT_EXCLUDES_DOTNET=(
  bin obj
)

# Build-system tags. These add only the artifact dirs the tool itself
# creates -- not lockfiles, not source.
readonly PROJECT_EXCLUDES_MAVEN=(target)
readonly PROJECT_EXCLUDES_GRADLE=(.gradle build)
readonly PROJECT_EXCLUDES_NODE=(
  node_modules .npm .yarn/cache .yarn/install-state.gz
  .pnpm-store .parcel-cache .turbo .cache
  dist build out .eslintcache coverage
)
readonly PROJECT_EXCLUDES_PYTHON=(
  __pycache__ '*.pyc' '*.pyo' '*.pyd'
  .pytest_cache .mypy_cache .ruff_cache .tox
  .venv venv env '*.egg-info' .eggs
  htmlcov .coverage 'coverage.xml'
)
readonly PROJECT_EXCLUDES_RUST=(target)

readonly PROJECT_EXCLUDES_WEBPACK=(.webpack-cache)
readonly PROJECT_EXCLUDES_VITE=(.vite)
readonly PROJECT_EXCLUDES_NEXTJS=(.next .next/cache .vercel)
readonly PROJECT_EXCLUDES_NUXT=(.nuxt .output)
readonly PROJECT_EXCLUDES_COCOAPODS=(Pods)

readonly PROJECT_EXCLUDES_LATEX=(
  '*.aux' '*.lof' '*.lot' '*.fls' '*.out' '*.toc'
  '*.fmt' '*.fot' '*.cb' '*.cb2' '.*.lb' '*.dvi' '*.xdv'
  '*-converted-to.*' '*.ps' '*.ist' '*.bbl' '*.bcf'
  '*.blg' '*-blx.aux' '*-blx.bib' '*.run.xml' '*.fdb_latexmk'
  '*.synctex' '*.synctex(busy)' '*.synctex.gz' '*.synctex.gz(busy)'
  '*.pdfsync' '*.rubbercache' 'rubber.cache' 'latex.out/'
  '*.alg' '*.loa' '*.nav' '*.pre' '*.snm' '*.vrb'
  '*.acn' '*.acr' '*.glg' '*.glo' '*.gls' '*.glsdefs' '*.slg' '*.slo'
  '*.sls' '*.idx' '*.ilg' '*.ind' '_minted*' '*.pyg' '*.nlg'
  '*.nlo' '*.nls' '*.pax' '*.upa' '*.upb' 'pythontex-files-/'
  '*.dpth' '*.md5' '*.auxlock' '*.tdo' '*.hst' '*.ver' '*.wrt'
  '*.bak' '*.sav' .texpadtmp '*.lyx~' '*.backup'
  '*.tps' './auto/*' '*.lol'
)

# ---------------------------------------------------------------------------
# Dispatch helpers
# ---------------------------------------------------------------------------

# Return the highest-priority framework type matching <dir>, or non-zero.
project::auto_detect() {
  local dir="${1:?project::auto_detect requires DIR}"
  file::is_directory "$dir" || return 1

  local type
  for type in "${PROJECT_TYPES_PRIORITY[@]}"; do
    if "project::is_${type}" "$dir"; then
      printf '%s' "$type"
      return 0
    fi
  done
  return 1
}

# Detect every tag (framework + tooling) that matches <dir>. Populates
# the global PROJECT_DETECTED_TAGS array. Always returns 0; empty array
# means "no signals found."
#
# Globals set: PROJECT_DETECTED_TAGS
project::detect_tags() {
  PROJECT_DETECTED_TAGS=()
  local dir="${1:?project::detect_tags requires DIR}"
  file::is_directory "$dir" || return 1

  local tag
  for tag in "${PROJECT_TAGS_ALL[@]}"; do
    if "project::is_${tag}" "$dir" 2> /dev/null; then
      PROJECT_DETECTED_TAGS+=("$tag")
    fi
  done
}

# Build a deduplicated union of exclusion patterns for the given tags.
# PROJECT_EXCLUDES_COMMON is always included first. Tag names with no
# matching array are silently skipped (no error).
#
# Globals set: PROJECT_UNIONED_EXCLUDES
project::union_excludes() {
  PROJECT_UNIONED_EXCLUDES=()
  local -A seen=()
  local tag varname item

  for item in "${PROJECT_EXCLUDES_COMMON[@]}"; do
    if [[ -z ${seen[$item]:-} ]]; then
      seen[$item]=1
      PROJECT_UNIONED_EXCLUDES+=("$item")
    fi
  done

  for tag in "$@"; do
    varname="PROJECT_EXCLUDES_${tag^^}"
    declare -p "$varname" &> /dev/null || continue
    local -n arr="$varname"
    for item in "${arr[@]}"; do
      if [[ -z ${seen[$item]:-} ]]; then
        seen[$item]=1
        PROJECT_UNIONED_EXCLUDES+=("$item")
      fi
    done
    unset -n arr
  done
}

# Parse the standard "[-r|--recursive] [target]" CLI used by archive-*
# and clean-all-* scripts. Sets two globals for the caller to consume:
#
#   PROJECT_OPT_RECURSIVE  0 or 1
#   PROJECT_OPT_TARGET     the resolved target (defaults to $PWD)
#
# Exits 0 on -h/--help. Returns non-zero on unknown flag.
project::parse_args() {
  PROJECT_OPT_RECURSIVE=0
  PROJECT_OPT_TARGET=""
  while (($#)); do
    case "$1" in
      -r | --recursive) PROJECT_OPT_RECURSIVE=1 ;;
      -h | --help)
        printf 'Usage: %s [-r|--recursive] [target]\n' \
          "$(basename -- "${0:-script}")"
        exit 0
        ;;
      --)
        shift
        PROJECT_OPT_TARGET="${1:-}"
        break
        ;;
      -*)
        log::error "unknown flag: $1"
        return 1
        ;;
      *) PROJECT_OPT_TARGET="$1" ;;
    esac
    shift
  done
  PROJECT_OPT_TARGET="${PROJECT_OPT_TARGET:-$PWD}"
}

# Resolve a user-supplied target ("." / "~/x" / relative path) to an
# absolute, existing directory. Errors out otherwise.
project::resolve_target() {
  local target="${1:-$PWD}"
  file::is_directory "$target" || return 1
  readlink -f -- "$target"
}

# Walk <root> and invoke <action_fn> with each subdirectory matching
# <detector_fn>. Skips non-matches silently. <action_fn> receives one
# argument: the absolute project root.
#
# Pruning: once a directory matches, the walker does NOT descend into
# it. This prevents archiving / cleaning the same project twice when
# nested (e.g. a Flutter project's android/ folder also has gradle).
#
# Usage: project::for_each_matching project::is_flutter "$root" my::action
project::for_each_matching() {
  local detector="${1:?project::for_each_matching requires DETECTOR_FN}"
  local root="${2:?project::for_each_matching requires ROOT}"
  local action="${3:?project::for_each_matching requires ACTION_FN}"

  file::is_directory "$root" || return 1
  command::exists "$detector" || {
    log::error "detector function not found: $detector"
    return 1
  }
  command::exists "$action" || {
    log::error "action function not found: $action"
    return 1
  }

  local resolved
  resolved=$(readlink -f -- "$root")

  # Two-pass: collect matches sorted lexicographically, then drop any
  # path that is a child of an earlier match. find can't conditionally
  # prune based on a shell function, so we do it ourselves.
  local matches=()
  local dir
  while IFS= read -r -d '' dir; do
    "$detector" "$dir" && matches+=("$dir")
  done < <(find "$resolved" -type d -print0 | sort -z)

  local kept=() last=""
  for dir in "${matches[@]}"; do
    if [[ -n $last && $dir == "$last"/* ]]; then
      continue
    fi
    kept+=("$dir")
    last="$dir"
  done

  if ((${#kept[@]} == 0)); then
    log::warn "no matching projects found under: $root"
    return 0
  fi

  for dir in "${kept[@]}"; do
    "$action" "$dir" || log::warn "action failed for: $dir"
  done
  log::info "processed ${#kept[@]} project(s) under: $root"
}
