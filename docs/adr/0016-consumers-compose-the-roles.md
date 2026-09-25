# 16. Consumers compose the roles; the collection ships no fixed set

- Status: accepted

## Chosen

The collection ships roles and a few single-purpose plays, never a play that runs a fixed set of roles on every host.
The consumer's plays list the roles each group runs, in order. No role declares a dependency on another; order lives in
the plays, and a role that needs an earlier one's work asserts the host state that work leaves.

## Why

One collection now serves cloud VMs and boards, x86 and ARM, with and without backups, an edge or a tailnet. A fixed set
forces every role onto every host, and every role then has to skip quietly wherever it does not belong — the silent
failure the assert rules exist to prevent. Listing a role is a choice, and a choice can state its needs.

Meta dependencies lost because they hide the order a converge's safety rests on — the firewall reading the effective
sshd config, fail2ban banning through an active firewall — and re-run the depended-on role wherever it is pulled in. An
assert on host state says the same thing, fails naming the role to add, and costs nothing when the order is right.

## Cost

Every consumer writes its own plays, and the recommended order is advice the collection cannot enforce. A consumer who
reorders learns from an assert, not from the structure.

Upgrading from a fixed set is a breaking change: each consumer rewrites the import as plays.

## Reverses

Ship a fixed play again. Every role whose secret it lists would have to skip on absence once more, and the asserts on a
role's own secret would go.
