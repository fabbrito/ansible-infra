# Changelog

All notable changes to `fabbrito.infra`. The version here, the version in `galaxy.yml`, and the git tag move
together — consumers pin the tag, so a change that is not released is a change nobody gets.

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
- `caddy` — the TLS edge from the official apt repo: route schema, Cloudflare origin certs, derived proxy trust, and URI
  redaction on both loggers.
- `monitoring` — Beszel hub and agent plus Dozzle, loopback-bound, reached over an SSH tunnel.

### Playbooks

- `baseline` — the five baseline roles in their load-bearing order; consumers `import_playbook` it.
- `bootstrap` — one-time creation of the deploy user on a fresh box.
- `update` — serial apt upgrade with a reboot when required.
