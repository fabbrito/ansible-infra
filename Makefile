# Thin Makefile — a discoverable entry point that delegates to scripts/.
# There are no converge targets here on purpose: this repo ships roles, it does
# not own an inventory and cannot reach a host. Converging is the consumer's job.
#
#   make            # show this help
#   make deps       # install the collections the roles depend on
#   make hooks      # point git at .githooks (once per clone)
#   make check      # fmt-check + lint (what CI runs)

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
check: fmt-check lint ## fmt-check + lint (what CI runs)

.PHONY: fmt
fmt: ## Format YAML/MD/JSON (prettier) + Bash (shfmt)
	./scripts/fmt.sh

.PHONY: fmt-check
fmt-check: ## Verify formatting without writing (no autofix)
	./scripts/fmt.sh --check

.PHONY: lint
lint: ## Syntax-check playbooks + ansible-lint + shellcheck + collection build
	./scripts/lint.sh

##@ Release

.PHONY: build
build: ## Build the collection tarball into $(COLLECTIONS_DIR)/
	ansible-galaxy collection build --force --output-path $(COLLECTIONS_DIR)
