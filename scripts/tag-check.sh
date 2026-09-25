#!/usr/bin/env bash
# Assert a tag matches the version a consumer installs: the built
# MANIFEST.json's, the only version an installed tree records.
#   ./scripts/tag-check.sh v1.0.1
# No errexit: each step is checked where it can fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Ansible refuses non-blocking stdio; pipe through cat (AGENTS.md > Shell).
exec </dev/null > >(cat) 2>&1

tag=${1-}
if [[ -z $tag ]]; then
	printf 'usage: %s <tag>\n' "$0" >&2
	exit 2
fi

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# build-check.sh leaves exactly one tarball there.
./scripts/build-check.sh || exit 1
tarballs=(.collections/build/*.tar.gz)

bold '==> tag matches galaxy.yml'

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
	exit 1
fi

green "  ok  $tag matches galaxy.yml"
