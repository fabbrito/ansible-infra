<!-- Title is the merge commit subject: type(scope): subject — lowercase, no trailing period, <= 72
chars. The types and scopes are the gate's, in .githooks/hooks.conf.

Write terse — cut every word the diff already says. A section with nothing to add is deleted, not
filled. -->

## What

<!-- What changes for a consumer. The diff says how. -->

## Why

<!-- What made it necessary: the problem, or the decision it enacts. Link the issue: Closes #123 -->

## Checklist

- [ ] `make check` green on every commit
- [ ] `make test` passes; a new template branch has a fixture
- [ ] `make sanity` passes
- [ ] Contract change: `README.md` and `CHANGELOG.md` in the same commit
- [ ] Nothing names a secret, host or consumer

## Notes

<!--
Only what the diff cannot say: a gotcha found, something deliberately not done, or a converge,
e.g. "converged a consumer on this branch, noble VM, twice; second run changed=0".

Never a Claude-Session trailer or any session URL, here or in a commit: history is permanent.
-->

<!--
Enacting a decision? The ADR lands in THIS PR, and only if the reasoning still holds now that the
code exists. Superseding one fully? Delete it; its number is never reused.
-->
