# 14. Roles assert preconditions and cheap postconditions, read from host state

- Status: accepted

## Chosen

Assert what the role needs before it acts, and what it promised after.

- **Preconditions** come first, before any task changes the host: the consumer's vars, plus the host state the role
  depends on. They read host state, **never a "role X ran" marker**, which proves a role ran once, not that its effect
  still holds. When one fails, the message names the role to add.
- **Postconditions are cheap and read-only:** a probe that writes nothing and reports no change, followed by an assert
  on the effective state. A probe that writes, restarts, or costs more than a read does not qualify.
- **Don't re-prove what the module proves.** "The package installed" and "the service started" stay out; a postcondition
  checks the effective state a module can report success without producing.
- **Asserts check state; goldens check the bytes.** An assert that restates what a template renders is a second copy of
  the logic, and the copy will drift.

The mechanics: assert rather than fail, quiet, related conditions bundled into one, and a message that reads as a
runbook — naming the variable or the state, its value, the consequence, and the fix, never a path into the consumer's
inventory.

## Why

The earlier rule let a role assert its inputs and nothing else, and was written for one fixed playbook where every role
ran in a known order on a known platform, so the consumer's vars were the only unknown.

Consumers compose roles themselves now, in any order and on any subset, across Debian-family hosts and boards. A role
can no longer assume what ran before it, and it cannot assume a task reporting success left the effective state it meant
to: a configuration drop-in can render correctly and still be overridden by an earlier include, and the host then
accepts passwords while every task is green.

## Cost

Every precondition costs a check and every postcondition a round trip, which is why they must be cheap. A role with many
batches its reads into one probe.

Read-only probes run in check mode by design. A postcondition on state that only a real run creates is gated, with the
gate commented.

Asserts never report a change, so the second converge still reports zero changed.

## Reverses

A converge-time harness against a real host, proving the same postconditions. The in-role asserts would then shrink back
to preconditions.
