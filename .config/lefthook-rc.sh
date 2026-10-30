# shellcheck shell=sh
# templates/base: copy to .config/lefthook-rc.sh. Every hook sources it before
# lefthook runs: hooks never see `mise activate`, so without it a hook runs
# whatever apt installed. No mise fails the hook rather than falling back.
if ! command -v mise >/dev/null 2>&1; then
	echo 'lefthook-rc: mise not on PATH -' \
		'https://mise.jdx.dev, then make deps' >&2
	exit 1
fi
# PATH alone, like base.mk: no eval of generated shell. mise's [env] is a
# repo's own lane.
mise_path=$(mise bin-paths | paste -sd: -) || exit 1
PATH="$mise_path:$PATH"
export PATH
