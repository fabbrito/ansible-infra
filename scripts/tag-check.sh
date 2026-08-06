#!/usr/bin/env bash
# Assert a release tag matches the version a consumer will actually install.
#   ./scripts/tag-check.sh v1.0.1     # or $GITHUB_REF_NAME on a tag build
#
# The one release invariant only this side can enforce. `ansible-galaxy` records
# no git ref anywhere in an installed tree, so the sole version a consumer can
# compare their pin against is MANIFEST.json's, built from galaxy.yml. Tag and
# manifest disagreeing tells them "pinned X, installed Y" and sends them to
# reinstall, which can never fix it. The same gap makes a moved or force-pushed
# tag install clean and match, undetectably: refusing it here is the only close.
#
# Reads the built MANIFEST.json rather than parsing `version:` out of galaxy.yml.
# scripts/lint.sh learned that one the hard way — quotes or a trailing comment
# break the parse — and this is the byte a consumer's gate actually reads.
#
# No errexit: each step is checked where it can actually fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

tag=${1-${GITHUB_REF_NAME-}}
if [[ -z $tag ]]; then
	printf 'usage: %s <tag>\n' "$0" >&2
	exit 2
fi

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

bold '==> tag matches galaxy.yml'

# Its own directory, emptied first, so the tarball is findable by glob and
# nothing here has to reconstruct the filename from a version it does not know.
build_out='.collections/tag-check'
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

if ! manifest=$(tar xzOf "${tarballs[0]}" MANIFEST.json); then
	red "  FAIL cannot read MANIFEST.json from ${tarballs[0]}"
	exit 1
fi

if ! version=$(printf '%s' "$manifest" | python3 -c \
	'import json,sys; print(json.load(sys.stdin)["collection_info"]["version"])'); then
	red '  FAIL MANIFEST.json has no collection_info.version'
	exit 1
fi

if [[ $tag != "v$version" ]]; then
	red "  FAIL tag $tag, but galaxy.yml ships $version"
	printf 'The tag and galaxy.yml'\''s version move together, in ONE commit.\n'
	printf 'A consumer resolves the tag, then reads %s from MANIFEST.json:\n' "$version"
	printf 'the two disagreeing reports as a stale install they cannot fix.\n'
	exit 1
fi

green "  ok  $tag matches galaxy.yml"
