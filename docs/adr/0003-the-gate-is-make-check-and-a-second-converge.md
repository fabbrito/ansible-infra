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
