#!/usr/bin/env bash
# ansible-test sanity. Run from repo root: ./scripts/sanity.sh
#
# Deliberately NOT part of `make check`: check is the pre-commit gate and stays
# fast, while this builds a venv per Python version on first run. CI runs both.
#
# No errexit: the staging steps guard themselves, and the one command that
# matters records its own status.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

if ! command -v ansible-test >/dev/null 2>&1; then
	red 'ansible-test not installed (it ships with ansible-core)'
	exit 1
fi

# ansible-test insists its working directory be physically inside
# <path>/ansible_collections/<ns>/<name>, and it resolves symlinks — so the
# symlink scripts/lint.sh stages is no use here (it lands back at the repo root
# and ansible-test refuses). A real copy is the only way to give it the layout
# it wants without moving the repo itself.
stage='.collections/sanity'
dest="$stage/ansible_collections/fabbrito/infra"
rm -rf "$stage" && mkdir -p "$dest" || exit 1

# .collections excluded or the copy contains itself; .ansible is local cache.
# .git is COPIED ON PURPOSE — see the guard below.
if ! tar -c -C . --exclude=./.collections --exclude=./.ansible . |
	tar -x -C "$dest"; then
	red "  FAIL could not stage a copy at $dest"
	exit 1
fi

bold '==> ansible-test sanity'
out=$(cd "$dest" && ansible-test sanity --color no 2>&1)
status=$?

# ansible-test enumerates files through git. Without a .git in the staged copy
# every one of the 34 tests reports "No tests applicable", it prints "All
# targets skipped" — and it exits 0. A gate that passes because it tested
# nothing is worse than no gate, so treat the skip as the failure it is.
if printf '%s' "$out" | grep -q 'All targets skipped'; then
	red '  FAIL every target skipped — the staged copy has no .git to enumerate'
	exit 1
fi

if ((status != 0)); then
	printf '%s\n' "$out"
	red '  FAIL ansible-test sanity'
	exit 1
fi

# The count is the tests ansible-test itself reports running, not a number kept
# in sync by hand: a core upgrade that adds a test shows up here.
ran=$(printf '%s\n' "$out" | grep -c '^Running sanity test ')
green "  ok  $ran sanity test(s)"
exit 0
