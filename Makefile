# Thin Makefile — a discoverable entry point that delegates to scripts/.
# There are no converge targets here on purpose: this repo ships roles, it does not
# own an inventory and cannot reach a host. Converging is the consumer's job.
# `make` lists the targets; each one's comment is its help string.

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
# leaving $(COLLECTIONS_DIR) empty. Expected, not a failed install.
.PHONY: deps
deps: ## Install/upgrade the Ansible collections the roles depend on
	ansible-galaxy collection install -r requirements.yml --upgrade -p $(COLLECTIONS_DIR)/

##@ Local checks

# A hook nobody enabled is worth nothing, and core.hooksPath is per-clone, so this
# is the one setup step besides `deps`. chmod too: git runs the shims directly, and
# a mode bit lost to a checkout or a zip download disables the gate silently.
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

##@ Release legs

# Out of `check` on purpose: the pre-commit hook runs check on every commit, and
# a first `sanity` run builds a sanity venv per supported Python.
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

.PHONY: build-check
build-check: ## Build the collection and inspect what the tarball ships
	./scripts/build-check.sh

# The whole release gate, because there is no CI: lanes, goldens, sanity, the
# tarball, then the tag against the built MANIFEST. Stamps galaxy.yml, refuses
# without the CHANGELOG section, and leaves the commit and tag on this machine.
.PHONY: release
release: ## Stamp, gate, commit and tag — VERSION=x.y.z [DRY_RUN=1]
	./scripts/release.sh $(if $(DRY_RUN),--dry-run) $(VERSION)

.PHONY: publish
publish: ## Send master and the tag up, then the GitHub release [DRY_RUN=1]
	./scripts/publish.sh $(if $(DRY_RUN),--dry-run)
