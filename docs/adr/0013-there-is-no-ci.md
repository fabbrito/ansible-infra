# 13. There is no CI; the maintainer runs the gate before merge

- **Status:** accepted
- **Date:** 2026-09-25
- **Supersedes:** [ADR-0012](0012-ci-is-hardened-at-the-fork-boundary.md)

## Context

CI ran `make check`, `make sanity` and `make test` on every push and PR. Every one of those is static, touches no host,
and runs the same on a laptop. So CI proved nothing the hooks and the release command could not, and it brought its own
attack surface: ADR-0012 existed only to guard it.

What a consumer gets is the tag. A green CI run on an untagged commit is evidence nobody installs.

## Decision

**No workflow runs on a push or a PR.**

- **Per commit:** the pre-commit hook runs the lanes in `.githooks/hooks.conf`, and `commit-msg` checks the message.
- **Per PR:** the maintainer checks out the branch and runs `make check` before merging. A contributor's green run is a
  claim, not proof.
- **Per tag:** `make release` runs every leg the hook skips (goldens, sanity, what the tarball ships) and checks the tag
  against the built `MANIFEST.json`. A release cannot be cut red.

## Consequences

- **ADR-0012's guards protect nothing now.** Fork-run approval and the `actions/*` allowlist are repository settings
  that still exist, but no workflow runs for them to guard. They are harmless, and they are the right starting point if
  a workflow comes back.
- **A PR shows no status check.** Merging without running the gate is possible, and no tool here can stop it.
- **Hooks are opt-in per clone** (`make hooks`). A commit made without them is caught at the next `make check`, before
  merge or before release, whichever comes first.

## What would change this

- **Enough outside contributors that running the gate by hand per PR stops scaling.** Then a workflow comes back, and
  ADR-0012's reasoning comes back with it, from the top: `pull_request` only, fork approval, the action allowlist.
- **Anything that must run on infrastructure we do not hold**, such as a converge against a disposable VM. That is a job
  a laptop cannot do, and it is the first real reason for a runner.
