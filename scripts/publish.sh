#!/usr/bin/env bash
# Push master and the tag `make release` cut, then a GitHub release with
# notes.sh's notes. The tag is the artifact: nothing goes to Galaxy.
#   make publish [DRY_RUN=1]
# A dry run touches neither origin nor gh, and prints the notes.
# No errexit: each step is checked where it can fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

die() {
	printf 'publish: %s\n' "$*" >&2
	exit 1
}

dry=false
if [[ ${1-} == --dry-run ]]; then
	dry=true
	shift
fi

refusals=0
refuse() {
	$dry || die "$@"
	printf 'publish: would refuse: %s\n' "$*" >&2
	((refusals += 1))
	return 0
}

tag=$(git describe --tags --exact-match HEAD 2>/dev/null) ||
	die 'HEAD carries no tag — make release first'
[[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "$tag is not a release tag"
[[ $(git branch --show-current) == master ]] || refuse 'not on master'
[[ -z $(git status --porcelain) ]] || refuse 'tree not clean'
grep -q "^version: ${tag#v}\$" galaxy.yml ||
	refuse "galaxy.yml is not stamped ${tag#v}"
command -v gh >/dev/null 2>&1 || refuse 'gh not found'

notes=$(mktemp "${TMPDIR:-/tmp}/infra-notes.XXXXXX") || die 'mktemp failed'
trap 'rm -f "$notes"' EXIT
./scripts/notes.sh "$tag" >"$notes" || die 'notes failed'

if $dry; then
	printf 'publish: would send master and %s to origin, then:\n' "$tag"
	printf '  gh release create %s --title "fabbrito.infra %s" --notes-file <notes>\n' \
		"$tag" "$tag"
	printf -- '--- notes ---\n'
	cat "$notes"
	((refusals > 0)) && exit 1
	exit 0
fi

git push origin master || die 'cannot send master'
git push origin "$tag" || die 'cannot send the tag'
gh release create "$tag" --title "fabbrito.infra $tag" --notes-file "$notes" ||
	die 'gh release failed'

printf 'publish: %s is up\n' "$tag"
