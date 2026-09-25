# Thin Makefile — a discoverable entry point that delegates to scripts/.
# There are no converge targets here on purpose: this repo ships roles, it does
# not own an inventory and cannot reach a host. Converging is the consumer's job.
#
#   make             # show this help
#   make deps        # install the collections the roles depend on
#   make hooks       # point git at .githooks (once per clone)
#   make check       # every hook lane over the working changes (the gate)
#   make sanity      # ansible-test sanity (CI; slow on a cold venv)
#   make test        # golden render tests (CI)
#   make check-codes # sweep for plan labels (manual)

.DEFAULT_GOAL := help
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Same tree scripts/lint.sh stages this collection into, so one collections path
# resolves both fabbrito.infra.* and the third-party deps.
COLLECTIONS_DIR := .collections

##@ Help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[1m<target>\033[0m\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Dependencies

# The "not part of the configured collections paths" warning is expected — no
# ansible.cfg here, and scripts/lint.sh exports the path where one is needed.
# Leave it: it is the guard that catches the same mistake in a consumer's tree.
# An ansible-core with bundled collections can satisfy every pin and skip,
# leaving $(COLLECTIONS_DIR) empty; CI's bare core populates it.
.PHONY: deps
deps: ## Install/upgrade the Ansible collections the roles depend on
	ansible-galaxy collection install -r requirements.yml --upgrade -p $(COLLECTIONS_DIR)/

##@ Local checks

# core.hooksPath is per-clone and git will not set it for you — a hook that
# nobody enabled is worth nothing, so this is the one setup step besides `deps`.
# chmod too: git runs the shims directly, and a mode bit lost to a checkout or
# a zip download disables the whole gate silently. The engine refuses bash
# below 4.4 itself, naming the version it found.
.PHONY: hooks
hooks: ## Enable the repo's git hooks (once per clone)
	git config core.hooksPath .githooks
	@chmod +x .githooks/githooks .githooks/commit-msg .githooks/pre-commit
	@.githooks/githooks version >/dev/null
	@printf 'hooks enabled — skip one commit with --no-verify\n'

# The gate is .githooks/hooks.conf: the lanes live there, this is a caller.
# Adding a check means adding a lane, not a target — a file no lane matches is
# never checked.
.PHONY: check
check: ## Run every hook lane over the working changes (the gate)
	.githooks/githooks check

.PHONY: check-codes
check-codes: ## Sweep for plan labels (manual, not in check)
	./scripts/check-codes.sh

.PHONY: fmt
fmt: ## Run the same lanes, writing (prettier --write, shfmt -w); never stages
	.githooks/githooks check --fix

##@ CI checks

# Out of `check` on purpose: the pre-commit hook runs check on every commit, and
# a first `sanity` run builds a sanity venv per supported Python. CI runs it.
.PHONY: sanity
sanity: ## ansible-test sanity against a staged copy of the working tree
	./scripts/sanity.sh

.PHONY: test
test: ## Render the golden fixtures and diff against tests/golden/expected
	./scripts/golden.sh

# Separate target rather than a flag on `test`, so accepting a new expectation is
# always a deliberate command with a diff to read afterwards.
.PHONY: golden-update
golden-update: ## Accept the current render as the expectation (READ THE DIFF)
	./scripts/golden.sh --update

##@ Release

.PHONY: build
build: ## Build the collection tarball into $(COLLECTIONS_DIR)/
	ansible-galaxy collection build --force --output-path $(COLLECTIONS_DIR)

# Out of `check` because it needs a tag to grade and there is none on a branch.
# CI runs it on every v* tag; run it yourself before tagging to catch the bump
# you forgot while the fix is still one amend away.
.PHONY: tag-check
tag-check: ## Assert TAG matches galaxy.yml's version (make tag-check TAG=v1.0.1)
	./scripts/tag-check.sh $(TAG)
