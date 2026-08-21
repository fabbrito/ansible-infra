#!/usr/bin/env bash
# Format. Run from repo root:
#   ./scripts/fmt.sh          (auto-fix)
#   ./scripts/fmt.sh --check  (verify only, no writes)
#
# No errexit: each step records its own failure in `fail`, so one bad formatter
# does not hide the rest.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

check=0
if [[ ${1:-} = '--check' ]]; then
	check=1
fi

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

# npx only. An array, not a string: the runner and its flag are two argv
# entries.
#
# bunx is removed, not left as a fallback. Bun sets O_NONBLOCK on inherited
# stdio and never clears it; the flag lives on the open file description, so it
# leaks into make and every later recipe. ansible-core in lint.sh then refuses
# the non-blocking stderr ("Ansible requires blocking IO"), surfacing as an
# unparseable `ansible --version` naming neither bun nor the cause. Hidden on a
# TTY, where bun restores the flags; fires wherever stdio is a pipe or a file —
# CI, any agent shell. As a fallback it would fire silently, and only on the
# machines that lack node.
js_runner=()
if command -v npx >/dev/null 2>&1; then
	js_runner=(npx --yes)
fi

fail=0

bold '==> prettier (YAML / Markdown / JSON)'
if ((${#js_runner[@]} > 0)); then
	# One braced pattern, not four. Prettier errors on a pattern that matches
	# nothing, and the tree has no `.yaml` — Ansible's layout is `.yml` — so a
	# separate '**/*.yaml' failed the gate on every run while reporting every
	# matched file clean. Braces keep `.yaml` covered if one ever lands.
	targets=('**/*.{yml,yaml,md,json}')
	mode='--write'
	if ((check)); then
		mode='--check'
	fi
	# PINNED, like CI's shfmt and galaxy.yml's collection majors. `@latest` made
	# the definition of "formatted" whatever npm published most recently, resolved
	# at commit time inside the pre-commit hook — so an upstream release could
	# turn the tree red and block every commit with nothing here having changed.
	# Bump it deliberately, in a commit that carries the reformat.
	"${js_runner[@]}" prettier@3.9.6 "$mode" "${targets[@]}" ||
		fail=$((fail + 1))
else
	red '  npx not found (install node) — skipping prettier'
	fail=$((fail + 1))
fi

bold ''
bold '==> shfmt (Bash)'
if command -v shfmt >/dev/null 2>&1; then
	# nullglob: a role with no shell contributes nothing, not a literal path.
	# .githooks/* is extension-less and matched by shebang; it is graded
	# because a hook that dies takes the gate's own enforcement with it.
	shopt -s nullglob
	sh_files=(scripts/*.sh roles/*/files/*.sh .githooks/*)
	shopt -u nullglob
	# -i 0 = tabs, -ci = indent case patterns. House style; see README.md.
	if ((check)); then
		shfmt -i 0 -ci -d "${sh_files[@]}" || fail=$((fail + 1))
	else
		shfmt -i 0 -ci -w "${sh_files[@]}" || fail=$((fail + 1))
	fi
else
	red '  shfmt not installed (go install mvdan.cc/sh/v3/cmd/shfmt@latest)'
	fail=$((fail + 1))
fi

bold ''
if ((fail == 0)); then
	green 'All checks passed'
	exit 0
fi

red "$fail failure(s)"
exit 1
