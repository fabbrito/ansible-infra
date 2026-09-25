#!/usr/bin/env bash
# Stamp, gate, commit, tag, on this machine; there is no CI.
#   make release VERSION=1.0.2 [DRY_RUN=1]
# Version, CHANGELOG heading and tag move together (AGENTS.md > Releases).
# A dry run writes nothing and reports every refusal.
# No errexit: each step is checked where it can fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

die() {
	printf 'release: %s\n' "$*" >&2
	exit 1
}

dry=false
if [[ ${1-} == --dry-run ]]; then
	dry=true
	shift
fi

version=${1-}
version=${version#v}
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	printf 'usage: %s [--dry-run] <x.y.z>\n' "$0" >&2
	exit 2
fi
tag=v$version
# notes.sh skips this subject.
subject="chore(galaxy): release $version"

refusals=0
refuse() {
	$dry || die "$@"
	printf 'release: would refuse: %s\n' "$*" >&2
	((refusals += 1))
	return 0
}

[[ $(git branch --show-current) == master ]] || refuse 'not on master'
[[ -z $(git status --porcelain) ]] || refuse 'tree not clean'
if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
	refuse "$tag exists — a release is never moved, cut the next patch"
fi
if git remote get-url origin >/dev/null 2>&1; then
	git fetch --quiet origin master || die 'cannot fetch origin'
	git merge-base --is-ancestor origin/master HEAD ||
		refuse 'origin/master has commits this branch lacks'
	# A tag absent here may be on origin; publish would collide.
	git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null
	case $? in
		0) refuse "$tag is on origin — never move a release" ;;
		2) ;;
		*) die 'cannot list tags on origin' ;;
	esac
fi
grep -q "^## $version\$" CHANGELOG.md ||
	refuse "CHANGELOG.md has no '## $version' section — write it first"

if $dry; then
	printf 'release: would stamp %s, gate, commit, tag\n' "$tag"
	((refusals > 0)) && exit 1
	exit 0
fi

# Stamped before the gate, so the gate proves the bytes that ship.
sed -i "s/^version: .*/version: $version/" galaxy.yml ||
	die 'cannot stamp galaxy.yml'
grep -q "^version: $version\$" galaxy.yml || die 'stamp did not take'

unstamp() { git checkout -- galaxy.yml; }

# tag-check builds the tarball through build-check.sh.
for leg in 'make check' 'make test' 'make sanity' \
	"./scripts/tag-check.sh $tag"; do
	if ! $leg; then
		unstamp
		die "$leg failed — nothing committed"
	fi
done

# The commit runs the hooks and can be rejected; a stamp left behind would
# refuse the next run as "tree not clean".
git add galaxy.yml || die 'cannot stage the stamp'
if ! git commit -qm "$subject"; then
	git reset -q galaxy.yml
	unstamp
	die 'commit failed — nothing committed'
fi
git tag -a "$tag" -m "$tag" ||
	die "committed, but tagging failed — finish it: git tag -a $tag -m $tag"

printf 'release: %s tagged — make publish sends it up\n' "$tag"
