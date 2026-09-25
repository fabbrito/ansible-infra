# 2. A converge can never lock us out

- Status: accepted

## Chosen

Ansible reaches a host over the very path it reconfigures. Where a task can sever that path, the guard runs first, in
the same run:

- The firewall opens the declared ingress ports and rate-limits the port effective sshd listens on **before** the policy
  flips to deny-by-default.
- The sshd role validates the fully merged configuration **before** the handler reloads; a syntax error aborts the play
  instead of asking sshd to load something broken.
- Root stays reachable over the provider-injected key as break-glass, while password authentication is off outright.
  Daily work goes through the unprivileged deploy user.

New tasks touching the firewall, sshd or the network path inherit the rule.

## Why

Reversed, either order does not fail loudly: the task succeeds and the host is gone. There is no console we control and
no out-of-band path back in, so a converge that drops its own connection cannot report it.

Validation reads every drop-in, because sshd does. Checking one file proves nothing about the configuration that loads.
The role prefers the check that prints the merged configuration; the older one inspects a runtime directory that is
absent on a socket-activated host once the upgrade restarts the server, and would fail before reporting a verdict.

## Cost

Task order inside those two roles is not stylistic. Reordering is a bug that manifests only on a host you can no longer
reach to fix it.

Break-glass root depends on a key held in the provider account. Lose that key and the last way into a misconfigured host
is gone with it.

## Reverses

Move the reconnect path off SSH — a console, or an agent that dials out — and the ordering rule stops being a safety
requirement.
