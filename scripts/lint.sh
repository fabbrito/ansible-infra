#!/usr/bin/env bash
# Ansible checks: ./scripts/lint.sh
#
# The `ansible` lane in .githooks/hooks.conf, as a script because a lane is
# exec'd as written — no redirect, and it inherits the caller's descriptors.
# ansible-core's check_blocking_io() runs at import of ansible.cli and exits
# if any of the three is non-blocking; there is no flag and no env var, so a
# harness handing us a non-blocking stderr can only be answered here. Fresh
# pipes through cat are blocking, which is the whole fix.
#
# Formatters are lanes. The golden render, ansible-test sanity and the
# collection build are release legs (scripts/release.sh), not commit-time.
#
# This repo is a collection, not a control node: no inventory, no host. The
# dry-run leg the consuming repo runs (--check --diff) has no equivalent here
# — what can be proven upstream is proven here, the rest is the consumer's
# gate. README.md, "Where the gate lives".
#
# A missing tool fails, never skips. No errexit: each level records its own
# failure, so one broken playbook does not hide the state of the rest.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

exec </dev/null > >(cat) 2>&1

playbooks_dir='playbooks'
min_core='2.18'
pass=0
fail=0

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# Enforce the ansible-core floor from meta/runtime.yml. An unparseable version
# cannot prove the floor, so it is fatal. It guards every later leg: linting
# roles against a core that cannot run them proves nothing.
bold '==> ansible-core floor'
cur_core=$(ansible --version |
	awk 'NR == 1 { gsub(/[^0-9.]/, "", $NF); print $NF }')
if [[ -z $cur_core ]]; then
	red '  ansible not found, or its --version output did not parse'
	exit 1
fi

# sort -V puts the lower version first. If that is not the floor, we are under.
oldest=$(printf '%s\n%s\n' "$min_core" "$cur_core" | sort -V | head -1)
if [[ $oldest != "$min_core" ]]; then
	red "  ansible-core $cur_core < required $min_core (see meta/runtime.yml)"
	exit 1
fi
green "  ok  $cur_core"

# The playbooks name their roles by FQCN, and ansible resolves those only through
# a collections path — the repo root BEING the collection root is not enough.
# Stage a symlink at <path>/ansible_collections/<ns>/<name> so a syntax-check
# resolves fabbrito.infra.* against the working tree, uncommitted edits
# included. Cheaper and more honest than rebuilding a tarball per run. `make
# deps` installs the third-party collections into the same tree, so one path
# serves both.
staged='.collections/ansible_collections/fabbrito'
mkdir -p "$staged" || exit 1
ln -sfn "$PWD" "$staged/infra" || exit 1
export ANSIBLE_COLLECTIONS_PATH="$PWD/.collections"

bold ''
bold '==> Syntax check'
for pb in "$playbooks_dir"/*.yml; do
	[[ -f $pb ]] || continue
	if ansible-playbook --syntax-check "$pb" >/dev/null 2>&1; then
		green "  ok  $pb"
		pass=$((pass + 1))
	else
		red "  FAIL $pb"
		ansible-playbook --syntax-check "$pb"
		fail=$((fail + 1))
	fi
done

bold ''
bold '==> ansible-lint'
if command -v ansible-lint >/dev/null 2>&1; then
	# The whole tree, not just playbooks/: here the roles are the product, and
	# the galaxy rules only fire when galaxy.yml is in scope.
	#
	# ANSIBLE_COLLECTIONS_PATH is dropped for this leg. ansible-lint stages its
	# own copy of the collection and resolves galaxy.yml's dependencies itself;
	# leaving ours exported makes it find two installs and warn on every run.
	# Dropping it also makes this the check that galaxy.yml's dependency list —
	# the SHIPPED one — actually resolves, rather than requirements.yml's copy.
	env -u ANSIBLE_COLLECTIONS_PATH ansible-lint . || fail=$((fail + 1))
else
	# A missing tool is a FAILURE, not a skip. This is the leg the README calls
	# the gate; skipping it and still printing "All checks passed" is how
	# unlinted work reaches a commit through the pre-commit hook.
	red '  ansible-lint not installed (pip install ansible-lint)'
	fail=$((fail + 1))
fi

bold ''
if ((fail == 0)); then
	green "All checks passed ($pass playbooks)"
	exit 0
fi

red "$fail failure(s)"
exit 1
