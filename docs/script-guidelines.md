# Script Guidelines -- authoring, reviewing & testing

A working brief for anyone writing **or reviewing** shell scripts anywhere in
this repo. Read this together with
[`docs/engineering-guidelines.md`](engineering-guidelines.md) (the authoritative
rules). This file does not replace them; it adds the **review** and **testing**
depth and consolidates the conventions into checklists.

If anything here conflicts with the engineering guidelines, the guidelines win
-- surface the conflict instead of silently choosing.

---

## 1. Repo map -- know which kind of script you're touching

The rules differ by location. Identify the type first.

| Path                                                  | Kind                                                               | Core rule                                                                             |
| ----------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| `lib/*.sh`                                            | Libraries                                                          | **Side-effect-free when sourced** -- only define functions/consts. No top-level work. |
| `bin/*.sh`                                            | Entry points (`bootstrap`, `doctor`, `linker`, `packages`, `task`) | The orchestration layer; honor `DRY_RUN`, exit codes matter.                          |
| `scripts/user/*.sh`                                   | User-facing commands (~80)                                         | Thin front-ends: arg-parse + `main()` + call into `lib/`. Provide `-h`/`-n`.          |
| `scripts/tasks/system/{OS_ID,OS_ID_LIKE,common}/*.sh` | Provisioning steps                                                 | Idempotent, `$SUDO_CMD`, re-runnable.                                                 |
| `scripts/tasks/external/{OS_ID,common}/*.sh`          | Build/install external tools                                       | Idempotent, version-pinned via `config/versions.conf` + `lib/build.sh`.               |
| `config/`                                             | Data, not code                                                     | packages, apt aliases, symlink maps, version registry.                                |
| `manifests/*.conf`                                    | Profiles                                                           | No shebang (intentional); list of tasks/packages/symlinks to run.                     |

**The mental model** (see the engineering guidelines §1): `bootstrap.sh` runs
SYSTEM_TASKS -> PACKAGES -> EXTERNAL builds -> SYMLINKS, driven by a manifest.

---

## 2. The house style (applies to every script)

Established in the engineering guidelines §2 (House style). In short:

- Small single-purpose functions named `module::verb_object`, plus a `main()` at
  the bottom that reads like an English table of contents. The function names
  and `log::*` lines are the documentation.
- **No long top-level procedural scripts**, no `# -- step 1 --` banner comments.

  If you're writing one, extract helpers first.

- Comments are for the non-obvious **why** (workarounds, hidden constraints,
  invariants) -- never to narrate **what** the code does. Every script starts:
  `set -Eeuo pipefail`, then source the library via the standard preamble:

```bash
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]:-$0}")")/../.." && pwd)}"
# shellcheck source=/dev/null

source "${DOTFILES_ROOT}/lib/bash-utilities.sh"
```

- **Use the library, don't reinvent it.** After sourcing you have, among others:
  `log::{debug,info,warn,error,fatal}`,
  `file::{move,copy,exists,is_regular,...}`, `dir::{create,remove}`,
  `os::{check_dependency,get_architecture}`, `command::exists`,
  `string::{next_available_path,trim}`, `confirmation::{seek,is_confirmed}`,
  `banner::print`, plus `build::*`, `http::*`, `source::*`, `archive::*`. Prefer
  these over raw `echo`/`mkdir`/`mv`/ hand-rolled checks.

---

## 3. Cross-cutting rules (the things reviews most often catch)

### 3.1 Idempotency (non-negotiable)

Every task and tool must be safe to re-run. Check current state and return early
if already applied (see `lightdm::enable_service_at_boot`: it checks
`systemctl is-enabled` first). For file-producing tools, **skip when the output
already exists** and skip already-processed inputs, so a second run is a no-op.

### 3.2 Honor `DRY_RUN`

Anything that changes the filesystem must check `${DRY_RUN:-0}` and, when set,
log what it _would_ do and change nothing. User tools expose this as
`-n/--dry-run`.

### 3.3 Privilege: `$SUDO_CMD`, never bare `sudo`

`$SUDO_CMD` is the elevation prefix (empty when root, `sudo` otherwise). Use it
for every privileged command.

### 3.4 OS dispatch

`OS_ID` / `OS_ID_LIKE` come from `/etc/os-release` (exported by `bootstrap.sh`).
Put OS-specific tasks in the matching `system/<OS_ID>/` dir; shared logic in
`common/`. Don't hard-code distro assumptions inline.

### 3.5 Graceful degradation vs hard failure

- A **missing optional/supplementary** dependency -> `log::warn` and continue
  with reduced function. Don't abort the whole run for a nice-to-have.
- A **missing required** tool, or a tool for a feature the user **explicitly
  asked for** -> `log::fatal` / `os::check_dependency ... || exit 1`. Fail
  clearly, don't silently skip what was requested.
- Check exactly the tools the **chosen path** needs, not a blanket list.

### 3.6 Offline / network must never hard-fail

Network steps (downloads, version fetches, git pulls) are **best-effort**: wrap
in `timeout`, fall back to cached state on failure, `log::warn`, and **exit 0**
so bootstrap never dies because the machine is offline. Validate `curl`/`git`
results before using them.

### 3.7 Destructive operations need a guard

Any tool that **moves or deletes the user's data**: print a summary, **prompt
for confirmation** (`confirmation::seek`), support `-y/--yes` to skip, and
**refuse** to proceed non-interactively (`[[ ! -t 0 ]]`) without `-y`. Never
silently overwrite -- compute a collision-free destination.

### 3.8 Machine-specific values via `local/env.sh`

Any path/value that can differ per machine -> `DOTFILES_*` read as
`${DOTFILES_FOO:?DOTFILES_FOO must be set in local/env.sh}`. All configuration
variables must be explicitly defined in `local/env.sh`. Hardcoded fallbacks in
scripts are forbidden to ensure a declarative, machine-specific configuration.
Add every new variable to `local/env.sh.example`. (Worked example: the
`nemo-actions` task.)

### 3.9 Error handling & exit codes

- `set -Eeuo pipefail` everywhere. Remember it makes unset vars and pipe
  failures fatal -- quote defaults (`${x:-}`) and don't let an expected non-zero
  in a condition abort (use `if cmd; then`, or `cmd || rc=$?`).
- Libraries `return` non-zero; entry scripts `exit`. Don't `exit` from a `lib/`
  function.
- Guard library entry points with `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` if
  they're also runnable.

### 3.10 Quoting, globbing, word-splitting

Quote expansions (`"$f"`), use arrays for arg lists (`cmd=(...); "${cmd[@]}"`),
iterate `find ... -print0` with `while IFS= read -r -d ''`, and `--` before
filename arguments where the tool supports it. Don't `ls | grep` to drive logic.

### 3.11 Don't over-engineer

No feature flags / fallbacks / validation for inputs that can't occur here.
Trust internal call sites; validate at boundaries (user input, external
commands, network). Don't extract a helper for two callers. Surface adjacent
issues to the user -- don't refactor unprompted.

---

## 4. Reviewing an existing script -- the process

1. **Classify** it (§1) and read it top-to-bottom. Does it follow the house
   style (§2)? Is there a `main()`? Is `lib/` logic leaking into a `bin`/task,
   or vice versa?
2. **Run the static gate** (§6.1) on it.
3. **Exercise it**: `--help`, then `--dry-run`, then a real run on a throwaway
   fixture, then **run it again** (idempotency). For tasks, dry-run via
   `bootstrap.sh --profile <p> --dry-run` or run directly.
4. **Probe the edges**: no args, a non-matching input, a missing dependency
   (mock it, §6.5), offline (§6.5), a path with spaces, an already-done state.
5. **Audit against §3** -- the cross-cutting rules are where most real bugs hide
   (idempotency, DRY_RUN, `$SUDO_CMD`, graceful degradation, quoting).
6. **Report**: bugs with `file:line`, then suggested enhancements separately
   (§7). Don't fix unrelated things silently.

### Frequent real bugs (seen in this repo)

- A `find ... -exec bash -c '...'` subshell that calls `lib/` functions
  **without sourcing the library inside the subshell** -> "command not found".
  (Use a `while read -d ''` loop instead, or source inside the `bash -c`.)
- Naming-scheme clashes: `string::next_available_path` produces `name_1`, while
  `file::move` is `mv --backup=t` -> `name.~1~`. Pre-compute collision-free
  paths.
- A long-running external command with **no progress output** looks frozen --
  log a "doing X ..." line before slow calls.
- Choosing a slow tool when a fast one exists (e.g. a scanner that reloads a
  huge DB per file vs a resident daemon). Measure if unsure.
- Trusting a tool's flag from memory -- **verify against current docs**
  (engineering guidelines §4.3); CLI flags, unit names, and config schemas drift
  between versions.

---

## 5. Proposing enhancements / new tools

- First check the existing surface (`make help`, `bin/doctor.sh --help`,
  `scripts/tasks/**`, `config/packages/*`, `config/symlinks/*`) -- extend, don't
  duplicate.
- Surface ideas to the user before building, in this form:
  > "While doing X I noticed Y (file:line). Worth a follow-up because Z. Do it
  > now or leave it?"
- New package -> `config/packages/*.txt` (+ alias in the package-manager conf),
  not hard-coded. New symlink -> `config/symlinks/*.conf`. New external tool ->
  `scripts/tasks/external/...` using `lib/build.sh` + a `config/versions.conf`
  entry. Enable it in the relevant `manifests/*.conf` (commented = opt-in).
- Match the response/altitude to the request; keep it concise.

---

## 6. Testing protocol -- required before reporting "done"

"It compiles" is not "it works" (engineering guidelines §4.1–4.2). Exercise the
change.

### 6.1 Static checks (every touched shell file)

```bash
bash -n <file>
shellcheck --severity=warning --exclude=SC1090,SC1091,SC2034,SC2154,SC2155 <file>
shfmt -d -i 2 -ci -bn -sr <file>

```

Repo-wide: `make check-repo` (pre-commit lint + `bash -n` on every script) is
the local CI equivalent; `make lint` needs `pre-commit` installed. `make doctor`
(`./bin/doctor.sh --profile desktop`) is a separate machine-state/symlink audit,
not a code check.

### 6.2 Behavior checks (run it)

- **Help / dry-run**: `--help` works; `--dry-run` lists actions and writes
  nothing.
- **Idempotency**: run twice -- the second run is a no-op / skips existing
  output.
- **Pipeline tasks**: `./bin/bootstrap.sh --profile <p> --dry-run` and read the
  full output, not just the exit code.
- **Edge inputs**: no args, non-matching input, paths with spaces,
  already-applied state.

### 6.3 Build throwaway fixtures (don't touch real data)

Work in `mktemp -d`. Create the minimal input the script consumes (a dummy file,
a fake repo, a small image/PDF). Never test destructive tools on real files --
copy a sample into the temp dir.

### 6.4 Mock dependencies you can't/shouldn't install

Put a fake executable first on `PATH` (a tiny script printing the expected
output and exit code) to test integration logic without the real tool -- e.g. to
prove a "malware found -> quarantine" branch, or a "tool missing -> warn/fatal"
branch. **Never silently `apt install` on the user's machine** to make a test
pass.

### 6.5 Failure-mode checks

- **Missing dependency**: run with the tool absent (mock or a restricted
  `PATH`); assert warn-and-continue (optional) or clean fatal
  (required/requested).
- **Offline**: simulate with `https_proxy=http://127.0.0.1:1` and a short
  timeout; assert cached fallback and exit 0.
- **Permissions / DRY_RUN**: confirm `DRY_RUN=1` changes nothing.

### 6.6 Honesty

If you genuinely can't test something (GUI, hardware, a tool not installed and
not mockable), **say so explicitly** in the summary -- don't claim success.
Report failures with the actual output; state skipped steps.

### Definition of done

Static checks pass on touched files · the changed behavior is exercised on a
real or synthetic fixture · idempotency / offline / missing-dep paths checked
where relevant · the summary states what was tested and any honest gaps.

---

## 7. Communication (when reporting back)

- Be concise; match length to the question. One- or two-sentence end-of-turn
  summary: what changed, what's next.
- Don't narrate internal deliberation. Reference code as `file:line`.
- Report outcomes faithfully: failures with output, skipped steps named, "done"
  only when verified.

---

## 8. Paste-friendly review checklist

- [ ] Right place for its kind (§1); `lib/` is side-effect-free; logic not
      leaking across layers.
- [ ] House style: `module::verb_object` helpers + `main()`; no step-by-step
      comment narration.
- [ ] `set -Eeuo pipefail`; sources `bash-utilities.sh`; uses
      `log::*`/`file::*`/... not raw shell.
- [ ] User tool: `-h/--help`, `-n/--dry-run`, sane no-arg behavior.
- [ ] Idempotent (re-run = no-op / skips existing output).
- [ ] `DRY_RUN` honored; `$SUDO_CMD` (never bare `sudo`); OS dispatch where
      relevant.
- [ ] Optional dep missing -> warn+continue; required/requested missing -> clean
      fatal.
- [ ] Network step -> `timeout` + cached fallback + exit 0 offline.
- [ ] Destructive? -> summary + confirm + `-y` + refuse non-interactive; no
      silent overwrite.
- [ ] Machine-specific values via `DOTFILES_*` with safe defaults +
      `env.sh.example` template.
- [ ] Quoting/arrays/`-print0` loops; no `ls|grep` logic; `--` before filenames.
- [ ] Tool flags verified against current docs (web-search), not memory.
- [ ] `bash -n` + shellcheck + shfmt clean; behavior + edges tested on a
      fixture.
- [ ] Enhancements surfaced separately; nothing unrelated changed silently.
