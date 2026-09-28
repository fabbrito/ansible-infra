# shellcheck shell=sh
# templates/base: copy to .config/lefthook-rc.sh. Sourced by every git hook
# before lefthook runs: mise's pinned tools first on PATH. Hooks never see
# `mise activate`, so without this a hook runs whatever apt installed and
# passes on the wrong version - no mise is a failed hook, not a fallback.
if ! command -v mise >/dev/null 2>&1; then
	echo 'lefthook-rc: mise not on PATH - https://mise.jdx.dev, then make hooks' >&2
	exit 1
fi
eval "$(mise env -s bash)" || exit 1
