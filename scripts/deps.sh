#!/usr/bin/env bash
# Install or upgrade the collections the roles depend on: ./scripts/deps.sh
# Into .collections, where lint.sh stages this collection too: one path
# resolves ours and the deps.
# No errexit: the one step is checked.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Ansible refuses non-blocking stdio; pipe through cat (AGENTS.md > Shell).
exec </dev/null > >(cat) 2>&1

# The path is lint.sh's only one: without it galaxy counts a copy in
# ~/.ansible as installed and skips it, and the syntax check never sees it.
export ANSIBLE_COLLECTIONS_PATH="$PWD/.collections"
if ! ansible-galaxy collection install -r requirements.yml --upgrade \
	-p .collections/; then
	printf 'deps: ansible-galaxy failed\n' >&2
	exit 1
fi
