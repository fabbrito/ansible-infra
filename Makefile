# Thin Makefile — a discoverable entry point that delegates to scripts/.
# There are no converge targets here on purpose: this repo ships roles, it does
# not own an inventory and cannot reach a host. Converging is the consumer's job.
#
#   make            # show this help
#   make deps       # install the collections the roles depend on
#   make hooks      # point git at .githooks (once per clone)
#   make check      # fmt-check + lint (the pre-commit gate)
#   make sanity     # ansible-test sanity (CI; slow on a cold venv)
#   make test       # golden render tests (CI)

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
# Both hooks name this target in their own header.
.PHONY: hooks
hooks: ## Enable the repo's git hooks (once per clone)
	git config core.hooksPath .githooks
	@printf 'hooks enabled — pre-commit runs "make check", commit-msg grades the subject\n'

.PHONY: check
check: fmt-check lint ## fmt-check + lint (the pre-commit gate)

.PHONY: fmt
fmt: ## Format YAML/MD/JSON (prettier) + Bash (shfmt)
	./scripts/fmt.sh

.PHONY: fmt-check
fmt-check: ## Verify formatting without writing (no autofix)
	./scripts/fmt.sh --check

.PHONY: lint
lint: ## Syntax-check playbooks + ansible-lint + shellcheck + collection build
	./scripts/lint.sh

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
