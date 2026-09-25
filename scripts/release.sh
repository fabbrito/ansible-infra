#!/usr/bin/env bash
#
# Cut a release on this machine: stamp, gate, commit, tag. Nothing leaves the
# machine — `make publish` does that.
#   make release VERSION=1.0.2 [DRY_RUN=1]
#
# There is no CI. This is the whole release gate, and it runs every leg the
# pre-commit hook leaves out because they are too slow to pay for per commit:
# the golden renders, ansible-test sanity, and what the tarball ships.
#
# galaxy.yml's version, CHANGELOG.md's heading and the tag move together —
# consumers pin the tag and read the version out of MANIFEST.json, so a
# disagreement reaches them as a stale install they cannot fix. The prose is
# yours: write the CHANGELOG section first, this refuses without it.
#
# A dry run writes nothing and reports every refusal instead of the first.
#
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
# The subject every release since 1.0.1 has used; notes.sh groups by scope.
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
	# A tag absent here may still be on origin: a stale clone, a pruned tag.
	# `git tag` cannot see it; publish would then collide.
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

# Stamped before the gate: a release is proven with exactly the bytes that
# ship, and the ansible lane re-resolves galaxy.yml on the way through.
sed -i "s/^version: .*/version: $version/" galaxy.yml ||
	die 'cannot stamp galaxy.yml'
grep -q "^version: $version\$" galaxy.yml || die 'stamp did not take'

unstamp() { git checkout -- galaxy.yml; }

for leg in 'make check' 'make test' 'make sanity' './scripts/build-check.sh'; do
	if ! $leg; then
		unstamp
		die "$leg failed — nothing committed"
	fi
done

# Last, because it reads the built MANIFEST.json rather than galaxy.yml: the
# byte a consumer's own gate compares their pin against.
if ! ./scripts/tag-check.sh "$tag"; then
	unstamp
	die 'tag-check failed — nothing committed'
fi

# The stamp is this script's to own all the way down: the commit runs the
# repo's own hooks and can be rejected, and a stamped galaxy.yml left behind
# refuses the next run as "tree not clean", naming nothing.
git add galaxy.yml || die 'cannot stage the stamp'
if ! git commit -qm "$subject"; then
	git reset -q galaxy.yml
	unstamp
	die 'commit failed — nothing committed'
fi
git tag -a "$tag" -m "$tag" ||
	die "committed, but tagging failed — finish it: git tag -a $tag -m $tag"

printf 'release: %s tagged — make publish sends it up\n' "$tag"
