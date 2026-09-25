#!/usr/bin/env bash
# Build the collection into .collections/build and inspect what it ships.
#   ./scripts/build-check.sh
# A green build proves nothing: omitting .collections from build_ignore once
# shipped a 259MB tarball. Inspect the contents.
# No errexit: each step is checked where it can fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Ansible refuses non-blocking stdio; pipe through cat (AGENTS.md > Shell).
exec </dev/null > >(cat) 2>&1

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

bold '==> collection build'

# Emptied, so the tarball is found by glob, not by parsing the version.
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

# Checked: an unreadable tarball must not read as zero stowaways.
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
