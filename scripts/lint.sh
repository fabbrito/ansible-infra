#!/usr/bin/env bash
# Static checks. Run from repo root: ./scripts/lint.sh
#
# This repo is a collection, not a controller: no inventory, no host. The
# dry-run leg the consuming repo runs (TEST_HOST=<host>, --check --diff) has no
# equivalent here — what can be proven upstream is proven here, the rest is the
# consumer's gate. README.md, "Where the gate lives".
#
# No errexit: each level records its own failure, so one broken playbook does
# not hide the state of the rest.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

playbooks_dir='playbooks'
pass=0
fail=0

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

# Enforce the ansible-core floor from meta/runtime.yml. An unparseable version
# cannot prove the floor, so it is fatal.
min_core='2.18'
cur_core=$(ansible --version |
	awk 'NR == 1 { gsub(/[^0-9.]/, "", $NF); print $NF }')
if [[ -z $cur_core ]]; then
	red 'ansible not found, or its --version output did not parse'
	exit 1
fi

# sort -V puts the lower version first. If that is not the floor, we are under.
oldest=$(printf '%s\n%s\n' "$min_core" "$cur_core" | sort -V | head -1)
if [[ $oldest != "$min_core" ]]; then
	red "ansible-core $cur_core < required $min_core (see meta/runtime.yml)"
	exit 1
fi

# baseline.yml names its roles by FQCN, and ansible resolves those only through a
# collections path — the repo root BEING the collection root is not enough. Stage
# a symlink at <path>/ansible_collections/<ns>/<name> so a syntax-check resolves
# capybaralabs.infra.* against the working tree, uncommitted edits included.
# Cheaper and more honest than rebuilding a tarball per run. `make deps` installs
# the third-party collections into the same tree, so one path serves both.
staged='.collections/ansible_collections/capybaralabs'
mkdir -p "$staged" || exit 1
ln -sfn "$PWD" "$staged/infra" || exit 1
export ANSIBLE_COLLECTIONS_PATH="$PWD/.collections"

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
	echo '  ansible-lint not installed; skipping'
fi

bold ''
bold '==> shellcheck'
if command -v shellcheck >/dev/null 2>&1; then
	# nullglob: a role with no shell contributes nothing, not a literal path.
	shopt -s nullglob
	sh_files=(scripts/*.sh roles/*/files/*.sh)
	shopt -u nullglob
	if shellcheck -x "${sh_files[@]}"; then
		green "  ok  ${#sh_files[@]} shell script(s)"
	else
		fail=$((fail + 1))
	fi
else
	echo '  shellcheck not installed; skipping'
fi

# Proves galaxy.yml parses and that build_ignore does not drop something the
# collection needs. Output lands in .collections/, which is gitignored.
#
# A successful exit proves nothing about what shipped: build_ignore is the only
# exclusion list the build reads, .gitignore is not consulted, and omitting
# .collections/ once vendored every dependency plus a symlink loop back to this
# repo — a 259MB tarball that built green. Inspect the contents, not the status.
bold ''
bold '==> collection build'
if ansible-galaxy collection build --force --output-path .collections >/dev/null 2>&1; then
	tarball=".collections/capybaralabs-infra-$(
		awk '$1 == "version:" { print $2 }' galaxy.yml
	).tar.gz"
	entries=$(tar tzf "$tarball")
	stowaways=$(printf '%s\n' "$entries" | while IFS= read -r path; do
		case $path in
			.collections/* | .ansible/*) printf '%s\n' "$path" ;;
		esac
	done)
	if [[ -n $stowaways ]]; then
		red '  FAIL tarball ships repo-local trees (add them to build_ignore):'
		printf '%s\n' "$stowaways" | head -5
		fail=$((fail + 1))
	else
		green "  ok  galaxy.yml builds ($(printf '%s\n' "$entries" | wc -l) entries)"
	fi
else
	red '  FAIL collection build'
	ansible-galaxy collection build --force --output-path .collections
	fail=$((fail + 1))
fi

bold ''
if ((fail == 0)); then
	green "All checks passed ($pass playbooks)"
	exit 0
fi

red "$fail failure(s)"
exit 1
