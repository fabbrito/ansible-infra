# 4. Caddy, from the official apt package

- **Status:** accepted
- **Date:** 2026-07-13

## Context

The obvious alternative is **nginx + certbot**: a reverse proxy from Ubuntu's apt, certificates from a second daemon on
a timer, renewal wired to a reload hook. It works, and it has worked in production for years in a lot of places. The
comparison below is against that.

## Decision

**Caddy**, installed from the **official apt package**, rendering a single `Caddyfile`.

Why Caddy over nginx:

- **Certificate lifecycle is a first-class feature**, not a second daemon plus a cron plus a reload hook glued
  alongside. This is the load-bearing reason. The entire Let's Encrypt story in
  [ADR-0006](0006-http-01-forced-and-the-ca-unpinned.md) amounts to "Caddy does it" — no certbot, no renewal timer, no
  `/.well-known` root to wire up, no reload hook to forget.
- **Caddy's defaults are safe; nginx's are a checklist you can silently fail**, and a missed item does not announce
  itself. Terse configuration is a means to that end, not the point of it.
- **One structured log stream.** With certbot, certificate failures land in `/var/log/letsencrypt` plus a systemd
  timer's exit status — a third format in a third place, unrelated to the access log. Caddy folds certificate management
  into its own logger as JSON alongside everything else. This is a genuine improvement, but it is _not_ free — see
  Consequences.

Why the apt package over an `xcaddy` build: it is what Caddy recommends for production, and it keeps upgrades riding
apt, alongside everything else the `os` role upgrades. Note that `unattended-upgrades` is _not_ what moves Caddy — it is
restricted to the Ubuntu security origins, and Caddy's repo is not one of them.

## Consequences

- **Standard modules only.** A third-party plugin — a DNS-challenge provider, a WAF — means leaving apt for an `xcaddy`
  build. That is a deliberate migration, not a tweak. [ADR-0006](0006-http-01-forced-and-the-ca-unpinned.md) is what
  keeps us from ever needing one.
- **Never run `caddy upgrade` on these hosts.** It self-replaces the binary in place, and the next operator-run
  dist-upgrade (`playbooks/update.yml`) clobbers it. `unattended-upgrades` will _not_ — it allows only the Ubuntu
  security origins — and that delay is exactly what makes the clobber a surprise. Caddy upgrades ride apt.
- **There are two log streams, and the one that matters is not on disk.** Caddy's `log` directive configures _only_ a
  site's HTTP access log; the role writes those per-vhost under `/var/log/caddy`. Everything else — including **all TLS
  and ACME certificate management** — goes to Caddy's `default` logger, which writes to stderr, which systemd captures.
  **Certificate failures live in `journalctl -u caddy` and nowhere else**, and nothing ships them off the box.

  _Amended by [ADR-0009](0009-secret-bearing-urls-are-redacted-in-every-logger.md)._ This bullet used to say the role
  does not configure the `default` logger. It does now — the error log carries the request URI, so a 5xx on a
  credential-bearing path would otherwise write that credential into the journal. The role configures the default logger
  for **redaction and nothing else**; everything above about where the two streams go is unchanged.

- **There is no certificate-expiry metric.** Caddy's `/metrics` on the admin endpoint covers Go runtime, the admin API,
  HTTP middleware, and reverse-proxy upstream health. Expiry alerting needs a blackbox probe or a scrape of the admin
  API — it is not something Caddy hands you.
- Reloads go through `caddy reload` against the admin API rather than `systemctl reload`; the role's handler says why.
