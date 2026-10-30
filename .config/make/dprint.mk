# templates/dprint: copy to .config/make/dprint.mk, `include` it after
# base.mk. lefthook.yml's lane over the whole tree: dprint.json says which
# files.
check::
	dprint check --allow-no-files

fmt::
	dprint fmt --allow-no-files
