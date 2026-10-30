include .config/make/base.mk # mise's tools on PATH; first, so every recipe's
include .config/make/dprint.mk
include .config/make/shell.mk
.DEFAULT_GOAL := help # base.mk defines `deps` first

# Delegates to scripts/ and lefthook. No converge targets: this repo
# reaches no host. A target's `##` comment is its help line.

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

# Appended to base.mk's deps, after the pinned tools. No `##`: the help line
# is base.mk's, and a second one would list deps twice.
deps::
	./scripts/deps.sh

# mise and dprint bump themselves; the hand pins in .config/upgrade-pins.tsv
# only hint. APPLY=1 is the only way to write, and a typo is refused rather
# than read as yes.
APPLY ?=
ifneq ($(filter-out 1,$(APPLY)),)
$(error APPLY is 1 or unset, got '$(APPLY)')
endif

.PHONY: upgrade
upgrade: ## Preview pin bumps; APPLY=1 bumps, formats and gates
	scripts/upgrade-tooling.sh $(if $(APPLY),apply)

##@ Local checks

# The gate is make's: base.mk's check:: and each template's, then this
# repo's ansible lane. Plain commands, not `lefthook run`: a hook is for git.
# fmt has no ansible lane - ansible-lint never runs with --fix.
check::
	./scripts/lint.sh

.PHONY: check-codes
check-codes: ## Sweep for plan labels (manual, not in check)
	./scripts/check-codes.sh


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
release: ## Stamp, gate, commit and tag - VERSION=x.y.z [DRY_RUN=1]
	./scripts/release.sh $(if $(DRY_RUN),--dry-run) $(VERSION)

.PHONY: publish
publish: ## Send master and the tag up, then the GitHub release [DRY_RUN=1]
	./scripts/publish.sh $(if $(DRY_RUN),--dry-run)
