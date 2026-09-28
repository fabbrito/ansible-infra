include .config/make/base.mk # mise's tools on PATH, `make hooks`
.DEFAULT_GOAL := help # base.mk defines `hooks` first

# Delegates to scripts/ and lefthook. No converge targets: this repo
# reaches no host. A target's `##` comment is its help line.

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
	@awk "$$HELP_AWK" $(MAKEFILE_LIST)

##@ Dependencies

# The path is lint.sh's only one: without it galaxy counts a copy in
# ~/.ansible as installed and skips it, and the syntax check never sees it.
.PHONY: deps
deps: ## Install/upgrade the Ansible collections the roles depend on
	ANSIBLE_COLLECTIONS_PATH=$(CURDIR)/$(COLLECTIONS_DIR) \
		ansible-galaxy collection install -r requirements.yml --upgrade \
		-p $(COLLECTIONS_DIR)/

##@ Local checks

# Lanes live in lefthook.yml: a new check is a job, not a target.
.PHONY: check
check: ## Run every lane over the working changes (the gate)
	lefthook run check

.PHONY: check-codes
check-codes: ## Sweep for plan labels (manual, not in check)
	./scripts/check-codes.sh

.PHONY: fmt
fmt: ## Run the same lanes, writing (prettier, shfmt); never stages
	lefthook run fix

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
