## What

<!-- What does this PR do? Keep it short. -->

## Why

<!-- Context / motivation. Link the issue: Closes #123 -->

## How

<!--
Notable implementation details, trade-offs, or things reviewers should look at.

This repo converges nothing. It ships what SOMEBODY ELSE'S converge will do, to a
fleet you will never see — so say what moves on their hosts once they adopt the
tag: what a re-run does, what restarts or is recreated, and whether an
already-converged box changes. Name anything left as an accepted risk.

A var whose absence makes a role do the same work differently is a contract, not
a default. Say which one this is.
-->

## Checklist

- [ ] `make check` passes, and every commit leaves it green — not just the tip
- [ ] `make test` and `make sanity` pass. A template change with **no** golden diff means you changed nothing, or the
      branch you touched has no fixture
- [ ] Roles stay re-runnable: a second converge changes nothing, `--check` survives, and no converge can lock the
      operator out
- [ ] Contract change (new required var, a default that stopped being safe, a renamed role)? `README.md`'s tables and
      `CHANGELOG.md` move in the same commit
- [ ] A new authoring doc or repo-local tooling path joins `build_ignore` in the same commit
- [ ] No secrets, credentials, hostnames or IPs — and nothing naming a consumer, a client, or their vendor
- [ ] Runbooks in `docs/` updated if a procedure or the reasoning behind it changed
- [ ] Release: `galaxy.yml`, the `CHANGELOG.md` heading and the tag move together — or say here that it lands separately

<!--
The gate that matters is NOT on this list, because this repo cannot run it: a
`--check --diff` against a real box with the diff read, and a second converge
reporting zero changed. Both belong to the consuming repo, on the tag they adopt.
-->
