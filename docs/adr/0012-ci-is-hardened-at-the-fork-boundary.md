# 12. CI is hardened at the fork boundary, and two of the three guards are not in the workflow

- **Status:** accepted
- **Date:** 2026-08-11

## Context

The repository went public so consumers can fetch a tag with no credential —
[ADR-0011](0011-distribution-is-a-git-tag-not-a-galaxy-publish.md) depends on it. Public plus Actions means anyone who
can open a fork PR can cause code to run in our CI, and the reflex is to treat that as the vulnerability. It is worth
being precise about what is actually exposed, because the answer changes which guard is worth having.

Nothing in this repo's CI holds a secret. There is no Galaxy token, because there is no publish. There is no vault,
structurally, and no inventory to attach one to. The workflow declares `permissions: contents: read` and the repository
default for `GITHUB_TOKEN` is read-only with PR approval denied. The classic supply-chain pwn — a fork PR edits the
workflow or the `Makefile` and exfiltrates a secret — needs `pull_request_target`, which grants the base repo's secrets
and a writable token to code checked out from the fork. This workflow uses `pull_request`, so a fork's run is
fork-scoped: secrets absent, token read-only.

What remains is a stranger executing arbitrary code on an ephemeral runner that holds nothing. Public repositories get
standard runners free, so that is not even a cost. Framed as "somebody could burn our compute", the exposure does not
justify much.

Framed correctly it justifies more. The asset is not the runner — it is **the tag a consumer pins**, which converges
hosts we never see. Any path by which a drive-by contribution influences what that tag contains is the thing worth
closing, and CI is one such path: a green check is evidence a reviewer leans on. So the guards below buy review
integrity and a bounded action surface, not secret protection. There is no secret here to protect.

## Decision

**Three guards. Only the first lives in a file this repo's gate can see.**

1. **`pull_request`, never `pull_request_target`.** In `.github/workflows/ci.yml`. This is the one that matters and the
   one a future workflow is most likely to get wrong, because `pull_request_target` is what you reach for the moment a
   job needs a secret.
2. **Fork PRs are held for approval from _every_ external contributor**, not GitHub's default of first-timers only. A
   run starts when a maintainer clicks, on the first PR and the hundredth.
3. **Only GitHub-owned actions are allowlisted** — `actions/*`. Marketplace-verified creators are not blanket-admitted,
   and there are no third-party patterns.

Guards 2 and 3 are repository settings. They exist in GitHub's configuration, not in the tree, which has consequences
below.

## Consequences

- **An external PR does not run until approved.** It sits at "waiting for approval" with no output. The PR template says
  so, because otherwise the contributor reads silence as breakage.
- **Adding a third-party action is a deliberate act.** The run fails at workflow start — before any step — naming the
  action. The unblock is one call, and `patterns_allowed` replaces rather than merges, so send the full list:

  ```bash
  gh api -X PUT repos/<owner>/<repo>/actions/permissions/selected-actions --input - <<'EOF'
  {"github_owned_allowed": true, "verified_allowed": false,
   "patterns_allowed": ["owner/action@*"]}
  EOF
  ```

  Actions defined in **this** repository (`uses: ./.github/actions/…`) are exempt from the allowlist entirely, so a
  composite action is the escape hatch that needs no setting change. Actions in _other_ repositories under the same
  owner are **not** exempt and need a pattern.

- **`make check` cannot see guards 2 and 3, and never will.** The gate is static and touches no network; repository
  settings drift silently. The workflow's header comment and this record are the only in-tree evidence they exist, which
  is why both name them explicitly rather than pointing at the GitHub UI.
- **`shfmt` is version-pinned, not checksum-pinned — accepted.** A tampered upstream release would run arbitrary code on
  a runner holding no secret, no writable token, and no artifact anyone consumes. The comment at that step names the
  condition that reverses it rather than leaving the omission to look like an oversight.
- **Actions are referenced at a moving major (`actions/checkout@v6`), not a SHA.** `sha_pinning_required` is off.
  Turning it on breaks every run until each `uses:` is rewritten to a commit, and it buys protection against GitHub
  compromising its own actions — a trust already extended by using the runner at all.

## What would change this

- **CI gains a step that publishes anything** — a Galaxy token, a signed artifact, a release upload. That reverses the
  central premise, and all of it reopens at once: checksum the `shfmt` download, SHA-pin every action, re-audit the
  token permissions per job. Reopen this record before adding the step, not after.
- **External contribution becomes routine.** Per-PR approval is friction proportional to volume. The answer is a
  trusted-contributor set, never relaxing the policy back to first-timers-only — that setting trusts a stranger's second
  PR on the strength of their first.
- **A third-party action becomes genuinely necessary.** Adding the pattern is the intended path, not a workaround. What
  would warrant reopening is the _third_ one, at which point `verified_allowed` is the honest setting rather than a
  growing pattern list nobody re-reads.
