.DEFAULT_GOAL := help

PROFILE ?= desktop

# `make help` — auto-generated from the `## ...` comments below each target.
.PHONY: help setup lint format check-repo versions check-registries check-links check-links-external status doctor heal bootstrap minimal-to-desktop backup check-backup

help:  ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
	  {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup:  ## Initialize local environment and secrets (non-destructive).
	@./bin/setup.sh

lint:  ## Run every linter & formatter (matches CI's lint job).
	pre-commit run --all-files

format:  ## Auto-format the codebase in place.
	pre-commit run --all-files || true
	./scripts/maintenance/format-config.sh

versions:  ## Refresh config/versions.conf from upstream.
	./scripts/maintenance/fetch-versions.sh

check-repo:  ## Full lint + bash -n syntax check (the local CI gate).
	$(MAKE) lint
	bash -n $$(find . -type f \( -name '*.sh' -o -name '*.bash' \) \
	  -not -path './.git/*' -not -path './apps/*')

check-registries:  ## Probe every URL in apps/**/*.txt + config/**/*.txt for dead links.
	./scripts/maintenance/check-registries.sh

check-links:  ## Check local internal links in Markdown files.
	pre-commit run lychee --all-files

check-links-external:  ## Check all external URLs in Markdown (slow, needs Docker).
	docker run --rm -v "$$(pwd):/init" lycheeverse/lychee --config /init/lychee.toml /init

status:  ## Show installed vs pinned version for every registry component (offline).
	./scripts/user/package-status.sh

doctor:  ## Audit machine state (symlinks, path, timers, wallpaper, etc).
	./bin/doctor.sh --profile $(PROFILE)

heal:  ## Auto-repair drift detected by doctor (symlinks, etc).
	./bin/doctor.sh --profile $(PROFILE) --fix

bootstrap:  ## Provision the machine (usage: make bootstrap PROFILE=desktop).
	./bin/bootstrap.sh --profile $(PROFILE)

minimal-to-desktop:  ## Convert a minimal install into a full desktop.
	./bin/bootstrap.sh --profile minimal-to-desktop

backup:  ## Run a manual restic backup.
	systemctl --user start restic-backup.service && journalctl --user -u restic-backup.service -f

check-backup:  ## Verify backup integrity (metadata + 1/7th of data).
	./scripts/user/restic-check.sh
