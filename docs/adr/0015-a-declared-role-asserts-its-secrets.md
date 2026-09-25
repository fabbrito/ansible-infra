# 15. A declared role asserts its secrets

- **Status:** accepted
- **Date:** 2026-09-25
- **Supersedes:** [ADR-0001](0001-secrets-in-vault-and-an-absent-secret-skips.md)

## Context

ADR-0001 made a role skip its work when its secret was absent. The reason was `baseline.yml`: every host ran every role,
so the first host had to converge before any credential existed. Skipping was the only way to avoid a chicken-and-egg
failure.

2.0 removes `baseline`, and consumers compose roles themselves. Listing a role is now a choice, and a choice states
intent. A host that lists `rclone` and converges without R2 credentials has no backups and no error, which is the silent
failure [ADR-0014](0014-roles-assert-pre-and-postconditions.md) exists to prevent. ADR-0001 also accepted that a
misspelled key looks the same as an absent one. That cost made sense when skipping was forced. It no longer is.

## Decision

**A role's own secret is a precondition. If it is absent, the role fails its assert and names the key.** If a host isn't
ready for a role, the consumer doesn't list that role yet.

Some features inside a role are optional, and the consumer turns one on by setting its key. Leaving the key unset leaves
the feature off. That is composition inside the role, not a skip:

- `docker` installs Docker. The registry login is a separate feature, and it runs only when its token is set.
- `monitoring`'s agent is paired by a key and token that the hub mints after its own first converge. That is a real
  two-phase bootstrap, so the agent stays off until both exist.

A role that has such a feature says so in `defaults/main.yml`, next to the key.

The parts of ADR-0001 that don't depend on skipping still hold. Secrets are supplied by the consumer and encrypted on
their side. This repo holds none. Any task that renders a secret carries `no_log: true`.

## Consequences

- **A misspelled role secret now fails the converge**, instead of converging "successfully" without the thing it was
  meant to configure.
- **Composition decides when a role joins.** A host that is waiting on credentials leaves the role out until they exist.
- **Consumers upgrading from 1.x must check their lists.** A role they listed without its secret now fails its assert.
  This is a breaking change and it goes in the 2.0 changelog.
- **Optional features keep the typo cost.** A misspelled key for an optional feature still leaves that feature off with
  no error. Where that matters, the role adds an explicit flag and asserts the key when the flag is on.

## What would change this

- **A playbook that runs a role on every host again.** Skipping would then be forced once more, for the same reason as
  ADR-0001.
