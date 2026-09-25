# 14. Roles assert preconditions and cheap postconditions, read from host state

- **Status:** accepted
- **Date:** 2026-09-25
- **Supersedes:** [ADR-0010](0010-roles-assert-their-preconditions-not-their-outcomes.md)

## Context

ADR-0010 let a role assert its inputs and nothing else. That rule was written for a collection with one fixed `baseline`
playbook: every role ran in a known order on a known platform, so the only unknown was the consumer's vars.

2.0 removes both. Consumers compose roles themselves, in any order and on any subset, and the target widens from Ubuntu
VMs to any Debian-family host, boards included. Now a role can't assume what ran before it, and it can't assume that a
task reporting `ok` left the effective state it meant to. `sshd` is the sharp case: a drop-in can render correctly and
still be overridden by an earlier `Include`, and the host then accepts passwords while every task is green.

## Decision

**Tiger Style, as far as Ansible allows: a role asserts what it needs before it acts, and what it promised after.**

- **Preconditions** come first, before any task changes the host: the consumer's vars (as ADR-0010 did), plus the host
  state the role depends on. For example, `network` asserts that NetworkManager is present, and `firewall` asserts that
  `netfilter-persistent` is absent.
- **Preconditions read host state, never "role X ran" markers.** A marker proves that a role ran once, not that its
  effect still holds. When a precondition fails, the message names the role to add.
- **Postconditions are cheap and read-only:** a `command:` or `stat` probe with `check_mode: false` and
  `changed_when: false`, followed by an assert on the effective state. Examples are `sshd -T` showing password
  authentication off, `ufw status` showing deny-default, and `/proc/swaps` matching the swap var. A probe that writes,
  restarts, or costs more than a read doesn't qualify.
- **Don't re-prove what the module proves.** "The package installed" and "the service started" stay out, which is
  ADR-0003's line. A postcondition checks the _effective_ state that a module can report `ok` without producing.
- **Asserts check state; goldens check the bytes.** The amendment to ADR-0010 still holds. An assert that restates what
  a template renders is a second copy of the logic, and it will drift.

The mechanics from ADR-0010 carry over unchanged: `ansible.builtin.assert` rather than `fail`, `quiet: true`, related
conditions bundled into one `that:`, and a `fail_msg` that reads as a runbook. The message names the variable or the
state, its value, the consequence, and the fix, never a path into the consumer's inventory.

## Consequences

- **Composition order is checked, not trusted.** If a role runs before the one it needs, it fails fast and names the
  missing role, instead of converging half a host.
- **`--check` still survives.** Read-only probes run in check mode by design. A postcondition on state that only a real
  run creates is gated `when: not ansible_check_mode`, and the gate is commented.
- **Postconditions cost a round trip each.** That is why they must be cheap. A role with many of them batches the reads
  into one probe.
- **A second converge still reports zero changed.** Probes carry `changed_when: false`, and asserts never report a
  change.

## What would change this

- **A converge-time test harness** (Molecule or similar, against a real host) proving the same postconditions. The
  in-role asserts would then shrink back to preconditions.
