# templates/base: copy to .config/make/base.mk, `include` it first - that is
# what makes Bash and -uo pipefail every recipe's, a repo's own included.
SHELL := /bin/bash
.SHELLFLAGS := -uo pipefail -c

ifeq ($(shell command -v mise),)
$(error mise not on PATH - https://mise.jdx.dev, then make deps)
endif
# Recursive: expanded per recipe, so a bump's pins reach `fmt` and `check`.
# A colon per path, none when mise prints nothing: an empty entry is `.`.
orig_path := $(PATH)
export PATH = $(shell mise bin-paths | sed 's/$$/:/' | tr -d '\n')$(orig_path)

.PHONY: deps hooks

##@ Tools and hooks

# Double-colon: a repo appends its own `deps::`, without `##` or help lists it
# twice. Plain `deps:` is a make error.
deps:: ## install the pinned tools and collections
	mise install

# Hooks do not travel with the tree. mise exec installs lefthook if make deps
# has not run.
hooks: ## install lefthook's hooks for this clone
	@git config --unset core.hooksPath || true
	mise exec -- lefthook install
	@echo 'hooks enabled - skip one commit with LEFTHOOK=0'

##@ Gate

# The whole tree, plain commands, not `lefthook run`. Double-colon: lanes append.
.PHONY: check fmt

check:: ## every lane over the whole tree, read only
	lefthook validate
	.config/make-phony.sh

fmt:: ## the same lanes, writing - never stages
	@:
