# Changelog

All notable changes to `fabbrito.infra`. The version here, the version in `galaxy.yml`, and the git tag move together —
consumers pin the tag, so a change that is not released is a change nobody gets.

A released tag is never repointed. 1.0.0 moved while the repo was private and nothing pinned it; going public ended
that, and the next correction is 1.0.1.

## Unreleased

- ADR-0011 records that distribution is a git tag and there is no Galaxy publish, along with the three things that would
  reopen it. The argument that publishing was needed for a downstream collection to depend on this one is false and the
  ADR says so: git dependencies resolve transitively, tested.

## 1.0.0

Initial extraction from the consumer repo these roles grew in, so a second team can take the same baseline without
taking the fleet it was written for.

### Roles

- `os` — apt baseline, swap before the upgrade that would OOM without it, hostname/FQDN, timezone, unattended-upgrades
  with a per-host reboot minute.
- `ufw` — declared ingress and an SSH rate-limit opened **before** the deny-default flip, so a converge cannot lock the
  host out.
- `fail2ban` — sshd and recidive jails, banning through ufw.
- `docker` — engine, compose v2, an optional registry login, and a weekly prune timer scheduled clear of the backup
  window.
- `rclone` — pinned upstream `.deb` verified by checksum, plus an R2 remote rendered only when its credentials exist.
  The `r2crypt` wrapper is both-passwords-or-neither, asserted and enforced at render.
- `caddy` — the TLS edge from the official apt repo: route schema, Cloudflare origin certs, derived proxy trust, and URI
  redaction on both loggers.
- `monitoring` — Beszel hub and agent plus Dozzle, loopback-bound, reached over an SSH tunnel. Asserts an admin
  identity, since an admin-less hub answers unauthenticated, and asserts the agent's key whenever its token is set.

### Playbooks

- `baseline` — the five baseline roles in their load-bearing order; consumers `import_playbook` it.
- `bootstrap` — one-time creation of the deploy user on a fresh box. Addressed by `-e target=<host>`, not `-l`.
- `update` — serial apt upgrade with a reboot when required.

### Gates

Static only — this repo owns no inventory and reaches no host, so the dry-run and second-converge legs stay the
consumer's ([ADR-0003](docs/adr/0003-the-gate-is-make-check-and-a-second-converge.md)).

- `make check` — formatting, playbook syntax, `ansible-lint` at the production profile, `shellcheck`, collection build.
  The pre-commit hook runs it, so every commit leaves it green.
- `make sanity` — `ansible-test sanity`. CI only; a cold run builds a venv per supported Python.
- `make test` — golden renders. Fixtures go through the real templates and the bytes are diffed against checked-in
  expectations. It catches what the other two structurally cannot: a config that is _valid_ and says the wrong thing —
  proxy trust on a host nothing fronts, a body cap clamped by a matcher-less default, an agent rendered with an empty
  token.

### Licensing and identity

- **Apache-2.0.** The pre-release tree said "All rights reserved".
- **The namespace is `fabbrito`**, matching the GitHub account that owns the repo — Galaxy grants namespaces from that
  identity, so a mismatch would have blocked any future publish. Every FQCN is `fabbrito.infra.*`.

### Installing

The consuming repo must declare `collections_path` in its `ansible.cfg` before installing. An install into a path
Ansible does not search leaves every `fabbrito.infra.*` FQCN unresolvable. See README, "Install".

The repo is public and installs over `https`, so no deploy key is needed — which is what makes it fetchable from a CI
runner. `git+ssh` still works.
