#!/usr/bin/env bash
# ansible-test sanity: ./scripts/sanity.sh
# A release leg: a cold run builds a venv per Python, too slow for the gate.
# No ignore files: a rendered script's shebang is `#!/usr/bin/env bash`, one
# ansible-test allows.
# No errexit: each step checks itself.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Ansible refuses non-blocking stdio; pipe through cat (AGENTS.md > Shell).
exec </dev/null > >(cat) 2>&1

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

if ! command -v ansible-test >/dev/null 2>&1; then
	red 'ansible-test not installed (it ships with ansible-core)'
	exit 1
fi

# ansible-test wants its cwd physically under ansible_collections/<ns>/<name>
# and resolves symlinks, so lint.sh's symlink will not do: stage a copy.
stage='.collections/sanity'
dest="$stage/ansible_collections/fabbrito/infra"
rm -rf "$stage" && mkdir -p "$dest" || exit 1

# .collections or the copy contains itself. .git on purpose: see below.
if ! tar -cf - -C . --exclude=./.collections --exclude=./.ansible . |
	tar -xf - -C "$dest"; then
	red "  FAIL could not stage a copy at $dest"
	exit 1
fi

bold '==> ansible-test sanity'
out=$(cd "$dest" && ansible-test sanity --color no 2>&1)
status=$?

# ansible-test enumerates through git: without .git every target is skipped,
# and it exits 0.
if printf '%s' "$out" | grep -q 'All targets skipped'; then
	red '  FAIL every target skipped — the staged copy has no .git to enumerate'
	exit 1
fi

if ((status != 0)); then
	printf '%s\n' "$out"
	red '  FAIL ansible-test sanity'
	exit 1
fi

# Counted from ansible-test's output, never kept by hand.
ran=$(printf '%s\n' "$out" | grep -c '^Running sanity test ')
green "  ok  $ran sanity test(s)"
exit 0
