# Changelog

All notable changes to `fabbrito.infra`. The version here, the version in `galaxy.yml`, and the git tag move together —
consumers pin the tag, so a change that is not released is a change nobody gets.

A released tag is never repointed. 1.0.0 moved while the repo was private and nothing pinned it; going public ended
that, and the next correction is 1.0.1.

## Unreleased

### Added

- `preflight`: read-only checks before any role changes the host — platform floor per distribution, ARMv6 refused, no
  root login, OpenSSH present, cloud-init finished, minimized image reported. Board-only: device tree present, hostname
  matches the inventory, break-glass warning.
- `os`: `jq` installed; `avahi-daemon` on boards; NTP servers via `os_ntp_servers`; extra unattended-upgrades origins
  via `os_unattended_origins`. Asserts its inputs and reads back swap, timezone, reboot time and NTP servers.
- `sshd`: the hardening drop-in, moved out of `os`. The merged config is validated before the reload, and the effective
  config is asserted, so an earlier drop-in that overrides ours fails the converge.
- `firewall`: refuses a host with `netfilter-persistent`. Rate-limits the ports the effective sshd config listens on,
  not a fixed 22. Reads back ufw active, deny-default and the limits.

### Changed

- `host_kind` (`board` | `vm`) is a new required contract var, asserted by `preflight`.
- `os` no longer touches sshd; add `sshd` to keep the hardening. `baseline` runs it right after `os`.
- `os` no longer upgrades or reboots during a converge: unattended-upgrades is the only upgrader and rebooter, and
  `playbooks/update.yml` is the explicit catch-up.
- `os` swap is opt-in: `os_swap_enabled` defaults to `false`. Set it on small VMs that relied on the old default.
- `os` writes its unattended-upgrades settings to a `52infra-unattended-upgrades` drop-in, no longer overwriting
  `20auto-upgrades` and `50unattended-upgrades`. Timers run daily on a VM and weekly on a board.
- `sshd` on a board refuses root login (`PermitRootLogin no`); a VM keeps key-only root as break-glass. Set
  `sshd_permit_root_login` to override.
- `ufw` role renamed `firewall`; vars `ufw_*` → `firewall_*`. `os` no longer installs `ufw`, `firewall` does.

### Upgrading from 1.x

- **Restore the package's `50unattended-upgrades` on every host 1.x converged.** 1.x overwrote it with a frozen
  security-only origin list; 2.0 leaves it to the package, so a 1.x host never picks up an origin a later package adds.
  Do not just delete it: dpkg never restores a deleted conffile, and without it Ubuntu upgrades nothing at all.

  ```bash
  sudo rm /etc/apt/apt.conf.d/50unattended-upgrades
  sudo apt-get install --reinstall -o Dpkg::Options::=--force-confmiss unattended-upgrades
  ```

  `20auto-upgrades` can stay: 1.x wrote the package's own defaults there.

## 1.2.0

### Changed

- `os` no longer names the box unless asked to. `os_hostname` previously defaulted to a derivation over
  `os_hostname_domain`, so a consumer who set neither still got the bare inventory key written to the host — renaming a
  box already carrying an FQDN, and rewriting the `127.0.1.1` entry the cloud image ships, on a converge that reported
  green. Both vars now default to empty and the hostname tasks skip together, which is what the README already claimed
  the row did.
- Minor rather than major: nothing became required, and the only behaviour that moved is the case that was wrong. A
  fleet that wants the old bare-key naming asks for it explicitly with `os_hostname: "{{ inventory_hostname }}"`.
- `os_hostname` is now the per-host override rather than a derived value — set it or `os_hostname_domain`, not both.

## 1.1.0

### Changed

- `bootstrap` asserts `deploy_authorized_keys` is defined and non-empty, before it creates anything. Empty was the case
  worth closing: the key loop was a no-op over `[]`, so the play went on to grant passwordless sudo and exited
  **green**, leaving an account nobody holds a key for on a box that reports itself converged. Unset died at the key
  loop instead, after the account existed but before the sudoers write.
- Minor rather than major, deliberately: [ADR-0001](docs/adr/0001-secrets-in-vault-and-an-absent-secret-skips.md) and
  the README contract both already listed the var as required, so the contract did not move — only its enforcement. No
  converged fleet can be running with it empty either, because such a host was never reachable as `deploy_user` to begin
  with.

## 1.0.1

- Citations in rendered files are qualified with the collection. `# Source:` paths, ADR references and `docs/` pointers
  now read `fabbrito.infra …`; unqualified, they resolved against the consuming repo's own tree, where `ADR-0006` is
  somebody else's decision and `roles/caddy/…` is somebody else's role. Affects the bytes of every rendered file, so the
  goldens moved with it.
- A `v*` tag now fails CI unless it matches `galaxy.yml`'s version. An installed tree records no git ref, so the version
  a consumer compares their pin against is `MANIFEST.json`'s; a tag that disagrees reaches them as "pinned X, installed
  Y", which no reinstall can fix. It also means a moved tag installs clean and matches — undetectable downstream, so
  this side is the only one that can refuse it. `make tag-check TAG=v1.0.1` runs the same guard before you tag.
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
