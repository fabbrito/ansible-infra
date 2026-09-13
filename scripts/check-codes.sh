#!/usr/bin/env bash
# Sweep the tree for plan labels — AGENTS.md > No internal codes.
#   ./scripts/check-codes.sh [pathspec...]
#
# A net, not a proof: one uppercase letter and digits (`P0`, `R3`, `B2.1`).
# Lowercase pairs are versions, multi-letter ones are standards. Out of
# `make check` on purpose: a look-alike must not block a commit.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Look-alikes: storage products the roles name.
allowed='R2|B2|S3'

# --untracked: a label not yet staged is the one worth catching. Exit 1 is
# no match; above that nothing was scanned.
hits=$(git -c core.quotePath=false grep --untracked -I -n -o -w -E \
	'[A-Z][0-9]+(\.[0-9]+)*' -- "$@")
if (($? > 1)); then
	printf 'check-codes.sh: git grep failed\n' >&2
	exit 2
fi

status=0
while IFS= read -r hit; do
	[[ -z $hit ]] && continue
	token=${hit##*:}
	where=${hit%:*}
	[[ $token =~ ^($allowed)$ ]] && continue
	# The rule's own example, and this file's.
	case ${where%:*}:$token in
		AGENTS.md:P0 | scripts/check-codes.sh:*) continue ;;
	esac
	printf '%s: %s\n' "$where" "$token" >&2
	status=1
done <<<"$hits"

if ((status != 0)); then
	printf '\n%s\n' 'Plan labels: describe the thing, or define it in docs/.' >&2
fi

exit $status
