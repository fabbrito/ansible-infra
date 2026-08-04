# 5. TLS mode follows DNS zone ownership

- **Status:** accepted
- **Date:** 2026-07-13

## Context

A zone held in the operator's own Cloudflare account and proxied terminates the browser's TLS connection at Cloudflare's
edge, and the origin presents a **Cloudflare Origin Certificate**. That certificate is **not publicly trusted** — it is
valid only because Cloudflare terminates in front of it. Show it to a browser directly and the browser rejects it.

**Some domains cannot be behind Cloudflare, because the zone belongs to someone else.** Proxying a name through
Cloudflare requires the zone's nameservers to point at that Cloudflare account. For a zone the operator does not hold,
they do not, and they will not.

This is not an accident of history that a future cleanup will resolve. It is a structural property of being handed a
hostname by a third party, and it recurs: the third party provisions a name inside their own zone and points an A record
straight at the box. DNS states the situation plainly — the name resolves to the box directly, and its nameservers are
theirs, at a registrar the operator has no account with. The hostname was given; the zone was not, and will not be.

## Decision

**The TLS mode of a route follows who holds the DNS zone.**

- **A zone the operator holds, in their Cloudflare account, proxied** → Cloudflare Origin Certificate, from a zone-wide
  blob in the vault.
- **A zone the operator does not hold, pointed at the box** → no Cloudflare, therefore no origin certificate. The
  certificate must be publicly trusted, and it comes from Let's Encrypt
  ([ADR-0006](0006-http-01-forced-and-the-ca-unpinned.md)).

A new domain is judged by one question, and it always has an unambiguous answer: **whose zone is it?**

## Consequences

- **Both TLS modes are permanent.** Neither is dead code, and neither is a transition state to be cleaned up later. The
  `caddy` role supports both, and the vault can hold origin-certificate blobs as well as an ACME setup.
- **A host that serves one third-party-owned name exercises Let's Encrypt only.** The Cloudflare path is not dead — it
  is the role's existing behaviour, and the next host with a name in a zone you hold uses it — but it is _unexercised
  there_, so it cannot be assumed proven by that host converging.
- **TLS mode is a per-route property**, so the route schema has to carry it.
- **The design must not preclude two names for one service.** Two names for the same service can land on _opposite
  sides_ of this rule — one in a zone the operator holds, one in a zone they do not — and need different TLS modes. They
  cannot then share a single Caddy site block, because a site block carries one `tls` directive. So the schema must make
  it **cheap for two routes to share one handler set**, rather than forcing every handler to be copy-pasted per name. No
  fleet has needed it yet. Nothing in the schema may make it impossible.
- **Gaining or losing control of a zone changes a route's TLS mode.** That is a configuration change, not a code change
  — which is the point of making ownership the rule rather than enumerating domains.
