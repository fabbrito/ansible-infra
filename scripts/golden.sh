#!/usr/bin/env bash
# Golden render tests. Run from repo root:
#   ./scripts/golden.sh            # render and diff against tests/golden/expected
#   ./scripts/golden.sh --update   # accept the current render as the expectation
#
# What this buys that `make check` cannot: ansible-lint and `caddy validate` both
# accept configs that are wrong in ways only the BYTES show — a trust block on a
# host nothing fronts, a body cap silently clamped by a matcher-less default, a
# redaction filter naming a prefix that never occurs. Asserts validate the
# consumer's input; goldens validate our output.
#
# No errexit: each step is checked where it can actually fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

update=0
case ${1-} in
	--update) update=1 ;;
	'') ;;
	*)
		printf 'usage: %s [--update]\n' "$0" >&2
		exit 2
		;;
esac

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

expected='tests/golden/expected'
actual='.collections/golden'

bold '==> golden render'
if ! render=$(ansible-playbook tests/golden/render.yml 2>&1); then
	printf '%s\n' "$render"
	red '  FAIL rendering the fixtures'
	exit 1
fi

if ((update)); then
	rm -rf "$expected" && mkdir -p "$expected" || exit 1
	cp -a "$actual"/. "$expected"/ || exit 1
	green '  updated tests/golden/expected — READ THE DIFF BEFORE COMMITTING'
	exit 0
fi

# A missing expected/ must not read as "nothing to compare, therefore fine":
# diff against a nonexistent directory is an error here, not a pass.
if [[ ! -d $expected ]]; then
	red "  FAIL no $expected — run ./scripts/golden.sh --update and review it"
	exit 1
fi

# -r walks both trees, so a rendered file with no expectation and an expectation
# with no render both surface as "Only in ..." rather than going unnoticed.
if diff_out=$(diff -ru "$expected" "$actual"); then
	shopt -s nullglob
	cases=("$actual"/*/*/)
	shopt -u nullglob
	green "  ok  ${#cases[@]} golden case(s)"
	exit 0
fi

printf '%s\n' "$diff_out"
red '  FAIL the render no longer matches tests/golden/expected'
printf 'If the change is intended: ./scripts/golden.sh --update, then read the diff.\n'
exit 1
