# Delegates to scripts/ and the hook engine. No converge targets: this repo
# reaches no host. A target's `##` comment is its help line.

.DEFAULT_GOAL := help
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# lint.sh stages this collection here too: one path resolves ours and the deps.
COLLECTIONS_DIR := .collections

define HELP_AWK
BEGIN {
	FS = ":.*##"
	printf "\nUsage: make \033[1m<target>\033[0m\n"
	printf "       make -n \033[1m<target>\033[0m prints its recipe, runs nothing\n"
}
/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }
/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 }
endef
export HELP_AWK

##@ Help

.PHONY: help
help: ## Show this help
	@awk "$$HELP_AWK" $(firstword $(MAKEFILE_LIST))

##@ Dependencies

# Expected: the "not part of the configured collections paths" warning (no
# ansible.cfg here), and an empty dir when bundled collections satisfy the pins.
.PHONY: deps
deps: ## Install/upgrade the Ansible collections the roles depend on
	ansible-galaxy collection install -r requirements.yml --upgrade -p $(COLLECTIONS_DIR)/

##@ Local checks

# core.hooksPath is per clone. chmod: a mode bit lost to a zip download
# disables the gate silently.
.PHONY: hooks
hooks: ## Enable the repo's git hooks (once per clone)
	git config core.hooksPath .githooks
	@chmod +x .githooks/githooks .githooks/commit-msg .githooks/pre-commit
	@.githooks/githooks version >/dev/null
	@printf 'hooks enabled — skip one commit with --no-verify\n'

# Lanes live in .githooks/hooks.conf: a new check is a lane, not a target.
.PHONY: check
check: ## Run every hook lane over the working changes (the gate)
	.githooks/githooks check

.PHONY: check-codes
check-codes: ## Sweep for plan labels (manual, not in check)
	./scripts/check-codes.sh

.PHONY: fmt
fmt: ## Run the same lanes, writing (prettier --write, shfmt -w); never stages
	.githooks/githooks check --fix

##@ Release legs

# Out of check: a cold sanity run builds a venv per Python.
.PHONY: sanity
sanity: ## ansible-test sanity against a staged copy of the working tree
	./scripts/sanity.sh

.PHONY: test
test: ## Render the golden fixtures and diff against tests/golden/expected
	./scripts/golden.sh

# A target, not a flag on test: accepting goldens is a deliberate command.
.PHONY: golden-update
golden-update: ## Accept the current render as the expectation (READ THE DIFF)
	./scripts/golden.sh --update

##@ Release

.PHONY: build-check
build-check: ## Build the collection and inspect what the tarball ships
	./scripts/build-check.sh

# The whole release gate, there being no CI. Commit and tag stay local.
.PHONY: release
release: ## Stamp, gate, commit and tag — VERSION=x.y.z [DRY_RUN=1]
	./scripts/release.sh $(if $(DRY_RUN),--dry-run) $(VERSION)

.PHONY: publish
publish: ## Send master and the tag up, then the GitHub release [DRY_RUN=1]
	./scripts/publish.sh $(if $(DRY_RUN),--dry-run)
