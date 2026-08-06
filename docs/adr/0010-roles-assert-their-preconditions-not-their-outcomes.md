# 10. Roles assert their preconditions, not their outcomes

- **Status:** accepted
- **Date:** 2026-07-17

## Context

[ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md) rules out testing _outcomes_: a check that the `apt`
module installed a package tests Ansible, not us. Desired-state modules already own that — canon is blunt about it (_"it
should not be necessary to test that services are started, packages are installed"_), and so are we.

But that leaves a real gap. Some invariants a role depends on are **not** expressible in the variable schema, and
getting them wrong does not error — it converges a host into a quietly broken state:

- `caddy` cannot represent "two proxy providers on one host." Trust is server-level and every vhost shares `:443`, so
  the ranges could union but `client_ip_headers` cannot. Nothing in the data model forbids naming two providers; the
  converge would just silently pick one.
- `caddy`'s ACME account email is optional YAML, but absent it, the issuer chain silently shrinks to Let's Encrypt alone
  ([ADR-0006](0006-http-01-forced-and-the-ca-unpinned.md)) — a host with fewer issuance lives than we think, and no
  error to say so.
- `rclone`'s R2 credentials are all-or-nothing: two of the three present renders a syntactically valid but broken `[r2]`
  remote, which fails at the first backup — hours later, in another role's timer.
- `monitoring`'s admin identity is the inverse case, and worth naming because it looks like the others and isn't. Absent
  it the hub still starts and still serves; it simply never creates a first user, and an admin-less hub answers to
  anyone who reaches its port. Skipping quietly is the unsafe option, so this one asserts.

Every one of these is a truth the schema can't make unrepresentable, and every one fails _silently_ if unguarded. That
is exactly the shape canon points `assert`/`fail` at, and every role with hand-authored input reaches for it the same
way.

## Decision

**A role validates its own preconditions inline, with `ansible.builtin.assert`, before it changes anything — and asserts
nothing else.**

The convention, as `caddy`, `rclone` and `monitoring` already practise it:

- **Assert early.** The checks run first in the role (or first in the guarded `block`), so a bad input fails before a
  single task touches the host — fail-fast, never half-configured.
- **The `fail_msg` is the runbook.** It names the offending variable, its value, the consequence, and the _scope_ it is
  set at — host-level, or fleet-wide vars or vault — never a path into the consumer's inventory, which this layer does
  not know. A bare "assertion failed" wastes the 3am reader's time.
- **`quiet: true` always.** Many small truths, no per-condition noise on the happy path.
- **Assert preconditions, not outcomes.** We assert what the schema can't encode and what would otherwise degrade
  silently — never that a package installed or a service started. That line is
  [ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md)'s, and it holds here.
- **Prefer `assert` to `fail`.** `assert` bundles the conditions with the message and reports nothing `changed`; we use
  no bare `fail`.

## Consequences

- **A bad input dies loudly, at converge time, before the host moves.** The class of silent half-broken state above
  becomes an immediate, self-explaining failure.
- **`--check` catches it too.** `assert` has full check-mode support, so the
  [ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md) dry-run flags a bad variable without a real run — one
  of the few things a dry-run can prove rather than merely suggest.
- **Assert never reports `changed`,** so it adds nothing to the second-converge gate it sits behind.
- **What cannot be asserted is documented, not faked.** `caddy` owes a third constraint — that `upstreams[].paths` stay
  literal strings — and cannot express it, so it says so in a comment rather than pretend a check exists. An assert we
  can't write is a landmine note, not a silent gap.
- **This is the test that tests _us_.** The only assertions in the repo are about our own inputs and assumptions; none
  are about Ansible's behaviour. That is what keeps [ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md)'s
  "no suite" honest — the validation we do write is the validation canon says we can't skip.

## Guidelines

**Reach for an assert only when both hold:**

- the invariant **cannot be made unrepresentable** in the variable schema, and
- getting it wrong **fails silently** — a crash-loop, a quietly degraded default, a wrong-but-green host — rather than
  erroring on its own.

If a typed default or the absent-secret skip ([ADR-0001](0001-secrets-in-vault-and-an-absent-secret-skips.md)) already
covers it, don't assert. If a desired-state module already errors on it — a missing package, a dead service — don't
assert either; that is the outcome-testing [ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md) rules out.

**When you do assert:**

- **Place it early** — first in the role, or first in the guarded `block`, so it fails before a task touches the host.
- **`quiet: true`, always** — many small truths, no happy-path noise.
- **The `fail_msg` is the runbook** — name the variable, its value, the consequence, and the scope it is set at, never a
  path into the consumer's inventory. Never a bare "assertion failed".
- **Bundle related conditions** into one `that:` list, not a task each.
- **Prefer `assert` to `fail`** — it carries the conditions, the message, and `quiet` together, and reports nothing
  `changed`.
- **What you cannot assert, document in place** — a comment naming the invariant and why it resists a check, never a
  silent gap or a faked one.

## Amendment — asserts check the input, goldens check the output (2026-08-06)

The discipline above stands unchanged. What follows is the boundary it does not reach, and the reason a proposal to
widen it was turned down.

**The proposal.** Rather than add a test harness, assert harder: cover every branch a template can take with
preconditions in the role, so a misconfigured host cannot converge. It is an attractive idea precisely because it reuses
a mechanism already here.

**Why it fails.** An assert reads the variables the consumer set. It cannot read the file the template produced. The
case that settled it was real and recent: `rclone`'s all-or-nothing assert on the crypt password pair was **correct, and
it passed** — it counted non-empty values — while the template beside it gated on `is defined`, which is true for the
empty string this repo uses to mean absent. Both halves were individually right. The render was wrong. No assert
reachable from the role's inputs could have seen it, because the disagreement was between the assert and the template,
not in the data.

That generalises. The failures worth catching in this layer are configs that are **valid and wrong** — a proxy-trust
block on a host nothing fronts, a body cap silently clamped by a matcher-less default, a redaction filter naming a
prefix that never occurs, an agent rendered with an empty token. Every one of them passes the tool's own validator.
Every one of them is visible the instant you look at the bytes.

**The line.**

> **Asserts validate the consumer's input. Goldens validate our output.**

Neither substitutes for the other, and reaching for one where the other belongs is the mistake this amendment exists to
prevent:

- **Do not add an assert to compensate for a missing fixture.** An assert that restates what a template does is a second
  copy of the logic, and the copy drifts — which is the `rclone` bug again, by construction.
- **Do not add a fixture to compensate for a missing assert.** A golden pins one input; a consumer supplies any input.
  What the schema cannot make unrepresentable still asserts, exactly as above.

The mechanism is `make test`, added under [ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md)'s amendment.
Where a derivation is security-critical, the harness **includes the role's own task file** rather than restating it —
`roles/caddy/tasks/routes.yml` and `roles/monitoring/tasks/pairing.yml` exist as separate files for that reason alone. A
harness that restates the thing under test proves only that the copy agrees with itself.
