#!/usr/bin/env bash
# A release's notes to stdout: commits since the previous tag, oldest first,
# grouped by scope, then the requirements.yml block a consumer pins.
#   scripts/notes.sh v1.0.2
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

slug=$(awk '$1 == "repository:" { print $2 }' galaxy.yml)
slug=${slug#https://github.com/}
[[ -n $slug ]] || die 'galaxy.yml has no repository'

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
