#!/usr/bin/env bash
# Build the collection and inspect what it would ship.
#   ./scripts/build-check.sh
#
# A release leg, not a commit-time one: nothing here changes between commits
# that do not touch galaxy.yml, and the answer only matters at a tag.
#
# Proves galaxy.yml parses and that build_ignore does not drop something the
# collection needs. A successful exit proves nothing about what shipped:
# build_ignore is the ONLY exclusion list the build reads, .gitignore is not
# consulted, and omitting .collections/ once vendored every dependency plus a
# symlink loop back to this repo — a 259MB tarball that built green. Inspect
# the contents, not the status.
#
# No errexit: each step is checked where it can actually fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# ansible refuses non-blocking descriptors, and the check runs at import.
# Fresh pipes through cat are blocking; see AGENTS.md > Agent shell gotchas.
exec </dev/null > >(cat) 2>&1

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

bold '==> collection build'

# A dedicated, emptied directory rather than .collections/ itself: it makes the
# tarball findable by glob, so nothing here re-parses galaxy.yml for the
# version. Deriving the path by awk meant any change to how `version:` is
# written — quotes, a trailing comment — silently pointed tar at a file that
# does not exist.
build_out='.collections/build'
rm -rf "$build_out" && mkdir -p "$build_out" || exit 1
if ! ansible-galaxy collection build --force \
	--output-path "$build_out" >/dev/null 2>&1; then
	red '  FAIL collection build'
	ansible-galaxy collection build --force --output-path "$build_out"
	exit 1
fi

shopt -s nullglob
tarballs=("$build_out"/*.tar.gz)
shopt -u nullglob
if ((${#tarballs[@]} != 1)); then
	red "  FAIL build produced ${#tarballs[@]} tarballs, expected 1"
	exit 1
fi

# tar's status is checked: an unreadable tarball must not read as zero
# stowaways, which is how this guard used to print "ok (1 entries)" while
# inspecting nothing.
if ! entries=$(tar tzf "${tarballs[0]}"); then
	red "  FAIL cannot read ${tarballs[0]}"
	exit 1
fi

# An allowlist, not a denylist: a new gitignored tree (.tmp/ once) ships
# silently until someone thinks to name it.
stowaways=$(printf '%s\n' "$entries" | while IFS= read -r path; do
	case $path in
		docs/agents/*) printf '%s\n' "$path" ;;
		MANIFEST.json | FILES.json | LICENSE | SECURITY.md) ;;
		README.md | CHANGELOG.md | requirements.yml) ;;
		docs/* | meta/* | playbooks/* | roles/*) ;;
		*) printf '%s\n' "$path" ;;
	esac
done)
if [[ -n $stowaways ]]; then
	red '  FAIL tarball ships what no consumer needs (add it to build_ignore):'
	printf '%s\n' "$stowaways" | head -5
	exit 1
fi

green "  ok  galaxy.yml builds ($(printf '%s\n' "$entries" | wc -l) entries)"
