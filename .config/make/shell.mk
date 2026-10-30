# templates/shell: copy to .config/make/shell.mk, `include` it after base.mk.
# The whole tree, shfmt's walk: symlinks out, `.editorconfig`'s `ignore = true`
# out. shellcheck cannot walk, so it takes shfmt's list.
check::
	shfmt -i 0 -ci -d .
	@mapfile -t f < <(shfmt -f .); if (($${#f[@]})); then shellcheck -x "$${f[@]}"; fi

fmt::
	shfmt -i 0 -ci -w .
