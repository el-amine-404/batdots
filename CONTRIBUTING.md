# Contributing to batdots

First off, thanks for taking the time to contribute! This project follows
production-level standards to ensure the framework remains stable, idempotent,
and maintainable across all supported distributions.

---

## Quick Start (4 Steps)

### 1. Setup your Environment

We use `pre-commit` to ensure code quality. It runs `shellcheck`, `shfmt`, and
hygiene checks automatically.

**Install pre-commit (Native preferred):**

- **Debian/Ubuntu:** `sudo apt install pre-commit`
- **Arch:** `sudo pacman -S pre-commit`
- **macOS:** `brew install pre-commit`
- **Fallback (pip):** `pip install --user pre-commit`

**Enable hooks:**

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

### 2. Branch from Main

Always keep your `main` branch clean and work on a feature branch.

```bash
git fetch origin
git checkout -b feat/your-feature-name origin/main
```

### 3. Make and Verify Changes

Follow the Coding Style and verify your changes locally before committing.

```bash
# Run all linters and formatters
make check-repo
```

### 4. Commit and Push

We use **Conventional Commits**. Your commit message must follow the format:
`<type>(<scope>): <subject>` (e.g.,
`feat(linker): add support for recursive symlinks`).

```bash
git add .
git commit -m "feat(scope): your descriptive message"
git push origin feat/your-feature-name
```

---

## Commit Standards

Enforced types:

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semi colons, etc (no code change)
- `refactor`: Refactoring production code
- `perf`: Code changes that improve performance
- `test`: Adding missing tests
- `chore`: Updating build tasks, package configs, etc

---

## Coding Style

- **Namespacing:** Functions must be `module::name` (e.g., `log::info`).
- **Safety:** Use `[[ ]]` instead of `[ ]`. Always quote variables: `"$VAR"`.
- **Indentation:** 2 spaces. No tabs.
- **Idempotency:** Every script must be safe to run multiple times.
- **Side-effects:** Files in `lib/` should only define functions, never execute
  them.

---

## Pull Request Process

1. **Title:** Use a Conventional Commit title (e.g., `feat: add support for X`).
2. **Description:** Explain the _why_ behind the change.
3. **Drafts:** Feel free to open a Draft PR if you want early feedback.
4. **CI:** Every PR triggers a full suite of linters and a smoke test.
