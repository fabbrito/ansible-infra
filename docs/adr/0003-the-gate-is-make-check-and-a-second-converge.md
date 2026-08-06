# 3. The gate is `make check` and a second converge

- **Status:** accepted
- **Date:** 2026-07-13

## Context

There is no unit-test suite in this repo, and there is not going to be one. A test asserting that the `apt` module
installed a package tests Ansible, not us. The thing that can actually go wrong here is a _host_, not an assertion — and
a host is not something a test suite can hold.

What we are left with is hand-written idempotence, which has a specific, quiet failure mode: a task that reports
`changed` on every run. The host ends up correct, so nothing looks broken — but every subsequent run is noisy, and real
drift hides in the noise.

## Decision

Three gates, in increasing order of truthfulness.

1. **`make check`** — static only, touches no host: formatting, playbook syntax, `ansible-lint` at the **production**
   profile, `shellcheck`, and a collection build. This is what CI runs, and every commit leaves it green.
2. **A dry-run** — `--check --diff` against a real host, read the diff.
3. **A second converge** — run the play twice. **The second run must report zero changed.** This is the closest thing to
   a real test that exists here, and it is the one that catches the failure mode above.

## Consequences

- **A changed-every-run task is a bug even when the host ends up correct.** That is the whole point of gate 3, and it is
  why a `command:` without `creates:`, a `stat` guard, or an explicit `changed_when:` does not pass review.
- **Check mode lies, and we accept that.** A task whose prerequisite package was never really installed cannot run under
  `--check`, so it is gated `when: not ansible_check_mode` to keep the dry-run reporting cleanly. A dry-run is therefore
  not proof — but an _unexpected_ diff is always real, which is enough to make it worth running.
- **Gate 1 syntax-checks every playbook and dry-runs none.** There is no host to dry-run against, so the
  `--check --diff` leg — and any exclusion a destructive play needs there — belongs to the consuming repo's gate, not to
  `scripts/lint.sh`.

## Amendment — two more static gates (2026-08-06)

The three gates above stand. Two more sit between gate 1 and gate 2, and both exist because gate 1 turned out to have a
blind spot the original text did not name: **it reads the tasks, never the bytes they produce.**

`ansible-lint` at the production profile will pass a template that renders a Caddyfile granting proxy trust to the whole
internet, because the task is a well-formed `template:` and the rendered file is somebody else's problem.
`caddy validate` will pass it too — it is valid Caddyfile. Nothing between "the YAML is clean" and "a host converged"
was looking at the output.

1. **`make sanity`** — `ansible-test sanity`, the 34 checks ansible-core ships. Cheap coverage of the things a
   collection is expected to get right and this repo had never been checked on. Out of `make check` on cost alone: a
   cold run builds a venv per supported Python, and the pre-commit hook runs `check` on every commit.
2. **`make test`** — golden renders. Fixtures go through the real templates and the resulting bytes are diffed against
   checked-in expectations. One fixture per _decision_, each naming the branch it pins.

Both are static, both touch no host, and CI runs them alongside `make check`.

The consequence worth stating plainly: **a template change with no golden diff means either you changed nothing or you
have no fixture for the branch you touched.** Adding a branch means adding a fixture, in the same commit. The mechanics,
and the two rules the layout cannot enforce, are in `tests/README.md`.

What this does **not** change: gates 2 and 3 remain the truthful ones. A golden proves we render what we meant to
render, never that the host likes it.
