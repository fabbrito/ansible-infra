#!/usr/bin/env bash
#
# A release's notes, to stdout: its commits since the release before it,
# oldest first, under their scope — an unscoped subject under its type. The
# first release has none before it, so its notes run from the root.
#   scripts/notes.sh v1.0.2
#
# The tag IS the artifact here: nothing is uploaded and nothing is published
# to Galaxy, so the notes carry the requirements.yml block a consumer pins.
#
# No errexit: each step is checked where it can fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

die() {
	printf 'notes: %s\n' "$*" >&2
	exit 1
}

tag=${1-}
if [[ -z $tag ]]; then
	printf 'usage: %s <tag>\n' "$0" >&2
	exit 2
fi
git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null ||
	die "no tag $tag"

prev=$(git describe --tags --abbrev=0 --match 'v[0-9]*' "$tag^" 2>/dev/null)
range=${prev:+$prev..}$tag

re_subject='^([a-z]+)(\(([a-z0-9-]+)\))?!?:'

declare -A lines
while IFS= read -r subject; do
	# The bump `make release` commits: the tag already says it.
	[[ $subject == 'chore(galaxy): release '* ]] && continue
	section=other
	if [[ $subject =~ $re_subject ]]; then
		section=${BASH_REMATCH[3]:-${BASH_REMATCH[1]}}
		subject=${subject/"${BASH_REMATCH[2]}"/}
	fi
	lines[$section]+="- $subject"$'\n'
done < <(git log --no-merges --reverse --format=%s "$range")
((${#lines[@]} > 0)) || die "no commits in $range"

mapfile -t sections < <(printf '%s\n' "${!lines[@]}" | sort)
first=true
for section in "${sections[@]}"; do
	$first || printf '\n'
	first=false
	printf '### %s\n\n%s' "$section" "${lines[$section]}"
done

# No origin — a bare clone — just means no links, and the pin block below
# still needs a URL, so it falls back to the one galaxy.yml declares.
slug=$(git remote get-url origin 2>/dev/null)
slug=${slug%.git}
slug=${slug#*github.com[:/]}
[[ -n $slug ]] || slug='fabbrito/ansible-infra'

# The whole consumer contract for a release: resolve this tag, read the
# version from MANIFEST.json, converge. A tag, never a branch — an upgrade is
# a chosen act, and a moved tag installs clean while shipping other bytes.
cat <<EOF

## Use it

\`\`\`yaml
# requirements.yml, in the consuming repo
collections:
  - name: git+https://github.com/$slug.git
    type: git
    version: $tag # a tag, never a branch
\`\`\`
EOF

if [[ -n $prev ]]; then
	printf '\n**Full changelog**: https://github.com/%s/compare/%s...%s\n' \
		"$slug" "$prev" "$tag"
fi
