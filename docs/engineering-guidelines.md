# Engineering Guidelines

The single source of truth for **how work is done** in this repo: architecture,
the house style, the constraints every script must honor, and the standard for
calling a change "done." Read this alongside:

- [`CONTRIBUTING.md`](../CONTRIBUTING.md) -- setup, commit format, PR process.
- [`docs/script-guidelines.md`](script-guidelines.md) -- the deeper authoring,
  **review**, and **testing** checklists for shell scripts.

If anything here conflicts with `CONTRIBUTING.md` on human-facing conventions,
`CONTRIBUTING.md` wins.

---

## 1. What this repo is

A profile-driven, self-healing dotfiles framework for Linux (primarily Debian 12
/ Ubuntu / Mint, with Fedora and Arch hooks). It is not "just config files" --
it's an opinionated toolkit for provisioning a machine from scratch and keeping
it in a known-good state.

### The mental model

```text
manifests/<profile>.conf
    │
    ▼
bin/bootstrap.sh   --►  runs four phases, in order:
    1. SYSTEM_TASKS    scripts/tasks/system/{OS_ID,OS_ID_LIKE,common}/<task>.sh
    2. PACKAGES        config/packages/<group>.txt via config/package-managers/<mgr>.conf
    3. EXTERNAL builds scripts/tasks/external/{OS_ID,common}/<task>.sh (versions in config/versions.conf)
    4. SYMLINKS        config/symlinks/<set>.conf, applied by bin/linker.sh
```

Profiles:

- `desktop` -- daily-driver workstation.
- `vm` -- minimal, no desktop.
- `minimal-to-desktop` -- converts a minimal Debian/server install into a full
  openbox/lightdm desktop in one shot.

### Directory layout

- **`apps/`** -- application-specific configuration files (symlink sources).
- **`bin/`** -- core management scripts (`bootstrap.sh`, `doctor.sh`,
  `linker.sh`, `packages`, `task`).
- **`config/`** -- declarative data: symlink maps, package lists, version
  registry, package-manager aliases. Data, not code.
- **`lib/`** -- reusable namespaced Bash library functions.
- **`scripts/`** -- user-facing commands (`scripts/user/`) and provisioning
  tasks (`scripts/tasks/`).
- **`manifests/`** -- machine profiles that select which tasks/packages/symlinks
  run.
- **`local/`** -- machine-specific, gitignored overrides (see §6).

### Self-healing layer

- `bin/doctor.sh` audits **machine** drift (broken symlinks, missing commands,
  stale PATH entries, version drift, secret-file permissions, backup timers).
  `--fix` auto-repairs symlinks; `make doctor` runs the audit and `make heal` is
  the repair shortcut.
- Code health (lint, `bash -n`) is a separate concern -- that's
  `make check-repo` and pre-commit/CI, not `doctor`. See §4.1 and §6.

---

## 2. House style: modular functions + `main()`

Scripts use small single-purpose helpers, namespaced `module::verb_object`, plus
a `main()` at the bottom that reads like an English table of contents. The
function names and `log::*` lines do the explaining -- comments do not narrate
what the code does.

**Good** (see `scripts/tasks/system/common/lightdm.sh`):

```bash
main() {
  banner::print "lightdm"
  lightdm::ensure_installed || exit 0
  lightdm::enable_service_at_boot
  lightdm::set_as_default_display_manager
  lightdm::select_slick_greeter
  lightdm::grant_greeter_home_access
}
main "$@"
```

**Avoid** long top-level procedural scripts with `# -- step 1 --` banner
comments. If you find yourself writing one, extract helpers first.

Comments are reserved for the genuinely non-obvious **why** (workarounds, hidden
constraints, subtle invariants) -- never for **what**; the function name is for
that.

### Standard preamble

Every script starts with `set -Eeuo pipefail`, then sources the library:

```bash
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null
source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
```

After sourcing you have, among others: `log::{debug,info,warn,error,fatal}`,
`file::{move,copy,exists,is_regular,...}`, `dir::{create,remove}`,
`os::{check_dependency,get_architecture}`, `command::exists`,
`string::{next_available_path,trim}`, `confirmation::{seek,is_confirmed}`,
`banner::print`, plus `build::*`, `http::*`, `source::*`, `archive::*`. Prefer
these over raw `echo`/`mkdir`/`mv`/hand-rolled checks.

### Naming

- Files: kebab-case (e.g. `media-convert.sh`).
- Functions and globals: `namespace::snake_case_name` with a unique prefix per
  module (e.g. `pkg::` for packages).

---

## 3. Non-negotiable constraints

- **Library files (`lib/*.sh`) must be side-effect-free when sourced** -- they
  only define functions and constants. Top-level work belongs in `bin/` or
  `scripts/tasks/`. Guard any runnable library with
  `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`.
- **`$SUDO_CMD` is the elevation prefix** (empty when already root, `sudo`
  otherwise). Use it for every privileged command -- never bare `sudo`.
- **`DRY_RUN=1` must be honored.** Anything that changes the filesystem checks
  `${DRY_RUN:-0}`, logs what it _would_ do, and changes nothing. User tools
  expose this as `-n/--dry-run`.
- **Idempotency is mandatory.** Every task and helper must be safe to re-run:
  check current state and return early if already applied. For file-producing
  tools, skip when the output already exists.
- **OS dispatch via `OS_ID` / `OS_ID_LIKE`** (from `/etc/os-release`, exported
  by `bootstrap.sh`). OS-specific tasks go in the matching `system/<OS_ID>/`
  dir; shared logic in `common/`. Don't hard-code distro assumptions inline.
- **`set -Eeuo pipefail` everywhere.** Quote defaults (`${x:-}`) and don't let
  an expected non-zero abort (`if cmd; then`, or `cmd || rc=$?`). Handle
  pitfalls like `((count++))` with `((count++)) || :`. Libraries `return`
  non-zero; entry scripts `exit`.
- **Network steps never hard-fail.** Downloads, version fetches, and git pulls
  are best-effort: wrap in `timeout`, fall back to cached state, `log::warn`,
  and exit 0 so bootstrap survives an offline machine. Validate `curl`/`git`
  results before using them.
- **Destructive operations need a guard.** Anything that moves or deletes user
  data prints a summary, prompts via `confirmation::seek`, supports `-y/--yes`,
  and refuses to run non-interactively (`[[ ! -t 0 ]]`) without `-y`. Never
  silently overwrite -- compute a collision-free destination.
- **Quote and array everything.** Quote expansions (`"$f"`), use arrays for arg
  lists (`cmd=(...); "${cmd[@]}"`), iterate `find ... -print0` with
  `while IFS= read -r -d ''`, and put `--` before filename arguments. Don't
  `ls | grep` to drive logic.

---

## 4. Contribution standards

These are the bar for any change, by anyone.

### 4.1 Don't introduce new bugs while fixing one

Every change leaves the repo at least as healthy as you found it. Before
declaring a task done, on every shell file you touched:

```bash
bash -n <file>
shellcheck --severity=warning --exclude=SC1090,SC1091,SC2034,SC2154,SC2155 <file>
shfmt -d -i 2 -ci -bn -sr <file>
```

`make check-repo` (pre-commit lint + `bash -n` on every script) is the local CI
equivalent. `make doctor` (`./bin/doctor.sh --profile desktop`) is a separate
machine-state/symlink audit, not a code check.

### 4.2 Test every feature or fix before reporting it done

"It compiles" is not "it works."

- New system task -> dry-run it (`bootstrap.sh --profile <p> --dry-run`),
  confirm it appears, and exercise idempotency (run twice; the second run is a
  no-op).
- New symlink entry -> apply the set and verify with `doctor.sh`.
- New script in `scripts/user/` -> invoke `--help` and one real argument set.
- New profile -> `bootstrap.sh --profile <new> --dry-run` and read the full
  output, not just the exit code.

Work in `mktemp -d` with throwaway fixtures; never test destructive tools on
real data. Mock dependencies you can't/shouldn't install by putting a fake
executable first on `PATH`. If you genuinely can't test something (GUI,
hardware), say so explicitly instead of claiming success. Report failures with
the actual output and name skipped steps.

### 4.3 Verify time-sensitive facts against upstream

Package names, repository URLs, systemd unit names, command-line flags, config
schemas, and greeter/DM/WM syntax all drift between versions. Confirm them
against current upstream docs rather than relying on memory before touching
them.

### 4.4 Suggest enhancements without over-engineering

When you spot an adjacent issue, surface it -- don't fix it silently or refactor
unprompted:

> "While doing X I noticed Y (`file:line`). Worth a follow-up because Z. Do it
> now or leave it?"

Three similar lines is fine. Don't extract a helper for two callers, add feature
flags/fallbacks, or validate inputs that can't occur here. Trust internal call
sites; validate only at boundaries (user input, external commands, network).

### 4.5 Honor the existing automation surface

Before adding a script, target, or workflow, check whether one exists:

- `make help` lists every top-level target.
- `bin/doctor.sh --help` lists every self-check.
- `scripts/tasks/{system,external}/{common,debian,ubuntu,fedora}/` is where
  provisioning steps live -- extend, don't replace.
- `config/packages/*.txt` is where package lists belong (not hard-coded in
  scripts); `config/symlinks/*.conf` is where new symlink mappings belong;
  external tools go in `scripts/tasks/external/...` using `lib/build.sh` plus a
  `config/versions.conf` entry, enabled in the relevant `manifests/*.conf`.

### 4.6 Machine-specific paths -> `local/env.sh`, no fallbacks

Any path or value that could differ across machines MUST live in `local/env.sh`:

- The variable name is **`DOTFILES_*`**.
- Read it as `${DOTFILES_FOO:?DOTFILES_FOO must be set in local/env.sh}` --
  never a hardcoded fallback in script logic.
- If the variable is set but invalid (path missing, not writable, wrong format),
  `log::fatal` and abort. An explicit bad value is a configuration error.
- Add an uncommented template line to `local/env.sh.example` so the variable is
  discoverable.

The `nemo-actions` task is a worked example: it resolves
`DOTFILES_NEMO_ACTIONS_DIR` against
`${XDG_DATA_HOME:-$HOME/.local/share}/nemo/actions` and fatals only if the
user-set override is bad.

---

## 5. Common gotchas

- `manifests/*.conf` files have no shebang -- intentional. Shellcheck flags
  `SC2148`; CI ignores `.conf` files. Don't "fix" it.
- The `local-init` task copies `local/*.example` -> `local/*` on first run and
  then **fatals** to force a review. Expected behavior, not a bug.
- `apps/` paths in symlink configs are relative to `DOTFILES_ROOT`; the target
  side is relative to `$HOME`.
- Conventional Commits are enforced by the `commit-msg` hook; install it with
  `pre-commit install --hook-type commit-msg`. The commit history is the record
  (there is no changelog file).

---

## 6. Command reference

`make help` is the authoritative catalog -- it prints every target with its
description straight from the `Makefile`. Run it instead of memorizing a list;
this doc deliberately doesn't copy it (a second copy only drifts).

Two distinctions worth fixing in your head, because the names invite confusion:

- **`make check-repo`** -- the code-health gate: pre-commit lint + `bash -n` on
  every script, the local equivalent of CI's lint job. Run it before committing.
- **`make doctor`** -- audits **machine** state (symlinks, PATH, version drift,
  timers), not code. `make heal` auto-repairs the symlink drift it finds.

Both entry points take flags `make help` doesn't surface, useful for previews:
`./bin/bootstrap.sh --profile <p> --dry-run` and
`./bin/doctor.sh --profile desktop --json`.
