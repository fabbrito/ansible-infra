# 2. A converge can never lock us out

- **Status:** accepted
- **Date:** 2026-07-13

## Context

Ansible reaches a host over SSH — through the very firewall and the very `sshd` it is reconfiguring. A task that severs
that path does not fail loudly; it succeeds, and then the host is gone. There is no console we control and no
out-of-band path back in. On a VPS reachable only over the network, losing SSH is losing the box.

This is not a hypothetical class of bug. Two tasks in this repo could each do it.

## Decision

**When a task can sever Ansible's own connection, the guard comes first, in the same run.**

The three live instances:

- The `firewall` role opens the declared ingress ports and rate-limits the ports effective `sshd` listens on **before**
  flipping the policy to deny-by-default. Reversed, the enable would drop the connection that was about to open port 22.
- The `sshd` role validates the full merged `sshd` config with `sshd -G` **before** the handler reloads. `sshd` reads
  every drop-in, so only the merged config is meaningful. A syntax error aborts the play rather than asking `sshd` to
  reload something broken. **`-G` wherever it exists** — `-t` stats the privsep directory `/run/sshd` and dies before it
  reports a verdict, and on a socket-activated host that directory is absent for the whole play once `dist-upgrade`
  restarts `openssh-server`. Releases too old for `-G` are not socket-activated, so `/run/sshd` is present and `-t` is
  safe there; the role probes for `-G` and its comments carry the detail.
- Root stays reachable over the provider-injected key (`PermitRootLogin prohibit-password`) as a **break-glass** path,
  while password authentication is disabled outright. Daily operations go through the unprivileged `deploy_user`.

## Consequences

- **Task order inside `firewall` and `sshd` is not stylistic.** Reordering those tasks is not a refactor; it is a bug
  that manifests only on a host you can no longer reach to fix it. The roles say so in comments, at the point where it
  matters.
- **Break-glass root depends on a key held in the provider account.** Lose that key and the last way back into a
  misconfigured host is gone with it.
- **New tasks inherit the rule.** Anything touching the firewall, `sshd`, or the network path has to answer "what
  happens if this runs and the next task doesn't?" before it lands.
