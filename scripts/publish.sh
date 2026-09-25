#!/usr/bin/env bash
#
# Publish what `make release` tagged: master and the tag to origin, then a
# GitHub release carrying scripts/notes.sh's notes. The tag IS the artifact —
# nothing is uploaded, and nothing goes to Galaxy: consumers install from the
# git tag (README.md, "Install").
#   make publish [DRY_RUN=1]
#
# A release is never moved after this. A bad one gets the next patch.
#
# A dry run touches neither origin nor gh, reports every refusal instead of
# the first, and prints the notes it would send.
#
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

# A file, not a string: the notes are a document, and `gh --notes-file` takes
# one. Their shape is notes.sh's problem, and it runs standalone.
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
