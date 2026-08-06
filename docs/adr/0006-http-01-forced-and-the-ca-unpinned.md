# 6. HTTP-01 is forced; the CA is not pinned

- **Status:** accepted
- **Date:** 2026-07-13

## Context

[ADR-0005](0005-tls-mode-follows-dns-zone-ownership.md) leaves some domains needing a publicly trusted certificate. Two
questions hide inside that, and they are independent: **how we prove control of the name**, and **which CA signs the
result**. The first is forced. The second is not, and reading them as one question is how a reader ends up believing we
pinned a CA we never pinned.

### Proving control

**DNS-01 is unavailable to us — not merely unattractive.** It requires writing a `_acme-challenge` TXT record into the
zone. But the domains that need a public certificate are _precisely_ the domains whose zone the operator does not hold —
that is _why_ they need one. Using DNS-01 would mean the third party handing over API credentials for their zone, or
delegating the challenge name by CNAME. Neither exists, and neither is unilateral to arrange.

**HTTP-01 works for exactly the reason DNS-01 does not.** The third party already pointed an A record at the box. Caddy
answers the challenge on port 80, on the host the name already resolves to. The one thing that was given is the one
thing HTTP-01 needs.

`ufw` already opens 80 and 443 on every host, so this costs no firewall change.

### Choosing a CA

Nothing about our situation forces a CA. Any ACME CA that speaks HTTP-01 can issue for these names, and Caddy ships with
a sensible default chain: Let's Encrypt, with ZeroSSL behind it as a fallback.

The fallback is not free of consequence, and it is not even always present — Caddy only adds ZeroSSL when an account
email is configured, because ZeroSSL requires an External Account Binding credential that Caddy mints from that address.
So the innocuous-looking act of setting an email is what pulls a second CA into the config. That coupling is invisible
in the Caddyfile and is worth knowing before it surprises someone.

## Decision

**HTTP-01. It is forced, not preferred.**

Anyone tempted to revisit this should first answer: how would we write a TXT record into a zone we do not control?

**The CA is deliberately left unpinned.** We run Caddy's default chain — Let's Encrypt first, ZeroSSL as fallback — and
we accept a certificate from either. Pinning to Let's Encrypt was considered and declined: the fallback is the only
thing standing between an upstream outage and an unreachable service, and on a host that serves one name, reachability
wins. **We accept the fallback knowingly; what we refuse is for it to be a surprise.** That is the entire reason this
section exists.

## Consequences

- **No wildcard certificates on these domains, ever.** Let's Encrypt issues wildcards only over DNS-01.
- **No DNS-challenge plugin, therefore no `xcaddy` build.** This is what keeps
  [ADR-0004](0004-caddy-from-the-official-apt-package.md) true: the apt package's standard modules suffice precisely
  because we never need a DNS provider module.
- **Port 80 must stay open and directly reachable** for the affected names. Renewal depends on it, not just first
  issuance — so a firewall change that looks harmless in January breaks certificates in March.
- **A route's site address must not carry an `http://` scheme, and automatic HTTPS must stay on.** Caddy answers the
  ACME challenge from the vhost automatic HTTPS inserts on port 80, ahead of the HTTP-to-HTTPS redirect. Take that vhost
  away and the challenge has no way to be answered — and nothing fails at converge time; issuance simply stops working.
  Any route schema has to keep this door open.

  **Correction — an earlier revision of this bullet said the address must stay a _bare hostname_, and that writing
  `https://<name>` removes the port-80 vhost. That is false, and it was tested, not reasoned about.** Caddy 2.8.4 and
  2.11.4, run live: `https://<name>` and bare `<name>` behave **identically** — both keep the port-80 vhost, both answer
  HTTP-01, both enable automatic HTTPS. The `https://` scheme only pins the port to 443. What actually disables
  automatic HTTPS is an **`http://`** scheme, `auto_https off`, or a site whose listeners are _all_ on the HTTP port
  (`caddyhttp/autohttps.go`: _"skip if all listeners use the HTTP port"_).

  The correction matters beyond pedantry: the false version made a **harmless** form look dangerous while leaving the
  **actually** dangerous one (`http://`) unnamed. A rule that forbids the wrong thing does not protect you from the
  right one.

- **An ACME route requires an account email, and the role refuses to converge without one.** This breaks the usual
  pattern — [ADR-0001](0001-secrets-in-vault-and-an-absent-secret-skips.md) has an absent value make a role do _less_,
  quietly. Here, quietly doing less means quietly changing which CAs can issue, because the email is what admits
  ZeroSSL. A silent drop from two CAs to one is not a smaller converge, it is a different one. It fails loudly instead.
  The email is an address, not a credential: it authenticates nothing, so it is plain config rather than a secret.
- **A certificate may be signed by ZeroSSL, and nothing will announce it.** The fallback fires only when Let's Encrypt
  has already failed, so it is an untested path that runs during an incident — and once it has run, renewals continue at
  ZeroSSL. Three things we are choosing to live with: Caddy reaches ZeroSSL through an EAB endpoint ZeroSSL does not
  document, whose removal would be silent; ZeroSSL has shipped breaking changes without notice before; and their free
  tier can be withdrawn. None of these breaks Let's Encrypt, which is the point — the fallback can rot without taking
  the primary with it.
- **Bring-up points at Let's Encrypt's staging CA, and only for that run.** The rate limit that bites is not the famous
  one: five duplicate certificates per week is generous for a single name, but **five failed validations per name per
  hour** is what a wrong A record or a shut port 80 burns through in an afternoon. Staging is where you find that out.
  The override is `caddy_acme_ca`, empty by default, and deliberately ephemeral — set it as an extra var for that run,
  never in a vars file, because a staging value that persists is a live site serving a certificate no browser trusts,
  with a green converge and nothing to catch it. Naming any CA explicitly also collapses Caddy's chain to that one CA,
  which is what makes the staging run mean staging and nothing else.
- **Certificate storage is disposable.** Caddy keeps issued certificates and its ACME account key under the `caddy`
  user's home. A reimage takes both; the host comes back with a new account and re-issues. That costs one certificate
  against the weekly duplicate budget and is not worth a backup — which would mean a TLS private key at rest off the
  box, and a restore ordered before Caddy starts, to save a request that is free.
- **Risk — the third party can re-point that A record without telling us.** Issuance succeeds today and renewal silently
  fails sixty days later. Nothing alerts on this: per [ADR-0004](0004-caddy-from-the-official-apt-package.md),
  certificate failures exist only in the host's journal, and nothing ships the journal anywhere. The account email was
  historically the backstop here — Let's Encrypt mailing an expiry warning — and Let's Encrypt is ending those
  notifications. Treat the email as a courtesy, not a monitor.
- **Risk — if the third party ever fronts the name with their own proxy or CDN, HTTP-01 breaks**, and DNS-01 was never
  available to fall back to. Restoring their hostname would mean asking them for a challenge delegation: a negotiation,
  not a configuration change.
- **Both risks are unmitigated where a host serves a third-party-owned name and nothing else**, knowingly: if that name
  breaks, the service is unreachable. It is a fair trade for a simple first host, and a bad one for anything past that.

  **The remedy is known and deliberately left on the shelf:** a second name in a zone you _do_ hold, serving the same
  service, Cloudflare-proxied on an origin certificate — which has **no ACME dependency at all** and so survives
  anything done to the third party's A record.

  It stays cheap to adopt only if we keep it cheap. [ADR-0005](0005-tls-mode-follows-dns-zone-ownership.md) keeps TLS
  mode a per-route property and requires that the schema not preclude two names for one service. Honour that and this
  becomes a configuration change. Violate it — bake one-name-per-service into the schema — and the day the third party
  re-points that record, the remedy is a refactor under pressure.
