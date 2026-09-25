# 1. Secrets live in the vault, and an absent secret skips rather than fails

- **Status:** superseded by [ADR-0015](0015-a-declared-role-asserts-its-secrets.md)
- **Date:** 2026-07-13

## Context

Roles need secrets: the pubkeys that bootstrap installs, a GHCR pull token, R2 credentials, Cloudflare
origin-certificate blobs. But a host has to be able to join the fleet _before_ those secrets exist — the first host
necessarily does, since there is nothing to converge against yet.

If a role failed when its secret was missing, the fleet would have a chicken-and-egg problem at exactly the moment it is
hardest to debug.

## Decision

Secrets are supplied by the consumer, encrypted at rest on their side — this layer holds none and has nowhere to put
one. Never in `defaults/`, never as a literal in a template. Any task that renders a secret carries `no_log: true`, or
the value lands in the play output and in CI logs.

**A role whose secret is absent skips its work; it does not fail.** `rclone` installs the binary but renders no config
without R2 credentials. `docker` installs the engine but skips the GHCR login without a token. Both are correct,
converged end states — not degraded ones.

## Consequences

- **A host can be bootstrapped and converged before its secrets exist.** This is what makes the first host possible at
  all, and it is why a new role must preserve the behaviour rather than assert its key is present.
- **Two exceptions, and they prove the rule.** `deploy_authorized_keys` is required: `bootstrap.yml` has nothing to
  install without it, so there is no meaningful work for it to skip. `monitoring_admin_password` is required because
  skipping is not a converged end state here — the hub starts, serves, and never creates a first user, so it answers to
  whoever reaches it. Assert when absence leaves nothing to do or leaves the host unsafe; skip everywhere else, and say
  in the role which one you chose.
- **Absence is indistinguishable from a typo, for a lone key.** A misspelled vault key does not fail the run — it
  silently skips the task that needed it, and the host converges "successfully" without the thing you meant to
  configure. Read the play output; a skipped task you expected to run is the signal. A typo inside a _grouped_ secret is
  the exception and fails loudly: `rclone`'s R2 triple and its crypt pair are asserted all-or-nothing
  ([ADR-0010](0010-roles-assert-their-preconditions-not-their-outcomes.md)).
