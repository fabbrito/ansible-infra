# 15. A declared role asserts its secrets

- Status: accepted

## Chosen

**A role's own secret is a precondition. Absent, the role fails its assert and names the key.** A host not ready for a
role is a host the consumer does not list it on yet.

An optional feature inside a role is different: the consumer turns it on by setting its key, and leaving the key unset
leaves the feature off. That is composition inside the role, not a skip, and the role says so beside the key.

Where it does not depend on skipping, the earlier rule still holds: secrets are supplied by the consumer, encrypted on
their side; this collection holds none; a task rendering one is `no_log: true`.

## Why

The earlier skip existed because one fixed playbook ran every role on every host, so the first host had to converge
before any credential existed. Skipping was the only way to avoid that.

Consumers list roles themselves now, and listing a role states intent. A host that lists the backup role and converges
without credentials has no backups and no error — precisely the silent failure the assert rules exist to prevent. The
earlier rule also accepted that a misspelled key looked like an absent one. That cost made sense only while skipping was
forced.

## Cost

**A misspelled role secret now fails the converge**, instead of converging successfully without the thing it was meant
to configure.

**A consumer upgrading from a fixed-playbook release must check its lists**: a role listed without its secret now fails
its assert. This is a breaking change.

**Optional features keep the typo cost.** A misspelled key for an optional feature still leaves it off with no error, so
where that matters the role adds an explicit flag and asserts the key when the flag is on.

## Reverses

A playbook that runs a role on every host again. Skipping is then forced once more, for the same reason as the first
record.
