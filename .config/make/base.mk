# templates/base: copy to .config/make/base.mk and `include` it first in the
# Makefile. mise's pinned tools first on PATH, so a target runs what the hooks
# run. No mise is an error, not a quiet fallback.
ifeq ($(shell command -v mise),)
$(error mise not on PATH - https://mise.jdx.dev, then make hooks)
endif
export PATH := $(shell mise bin-paths | paste -sd: -):$(PATH)

.PHONY: hooks

##@ Hooks

# Once per clone, and after a bump in mise: hooks do not travel with the tree.
# core.hooksPath is unset first - a leftover would hide lefthook's hooks.
# mise exec, not PATH: PATH was read before the install.
hooks: ## install the pinned tools and lefthook's hooks for this clone
	mise install
	@git config --unset core.hooksPath || true
	mise exec -- lefthook install
	@echo 'hooks enabled - skip one commit with LEFTHOOK=0'
