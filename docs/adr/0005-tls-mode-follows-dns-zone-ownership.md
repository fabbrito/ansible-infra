# 5. TLS mode follows DNS zone ownership

- Status: accepted

## Chosen

The TLS mode of a route follows who holds the DNS zone.

- **A zone the operator holds, in their Cloudflare account, proxied** → a Cloudflare origin certificate, from a
  zone-wide blob in the vault.
- **A zone the operator does not hold, pointed straight at the host** → no Cloudflare, therefore no origin certificate.
  The certificate must be publicly trusted, and it comes from an ACME issuer (ADR-0006).

A new name is judged by one question with an unambiguous answer: whose zone is it? Gaining or losing a zone is then a
configuration change, not a code change — which is the point of making ownership the rule rather than enumerating names.

## Why

An origin certificate is valid only because Cloudflare terminates in front of it; shown to a browser directly, the
browser rejects it.

Some names cannot be behind Cloudflare at all. Proxying requires the zone's nameservers to point at the operator's
account, and a zone handed over by a third party never will. This is structural, not leftover history: the third party
provisions a name inside their own zone and points a record at the host. The hostname was given; the zone was not.

## Cost

Both modes are permanent. Neither is dead code or a transition state to be cleaned up, and the role and the vault carry
both. A host serving one third-party-owned name exercises the ACME path only, so the Cloudflare path is unexercised
there and that host converging does not prove it.

TLS mode is a per-route property, so the route schema must carry it — and must keep two names for one service cheap. Two
names can land on opposite sides of this rule and need different modes, so they cannot share one site block. No fleet
has needed it yet; nothing in the schema may make it impossible.

## Reverses

Hold the zone of every name served, or stop proxying and require a publicly trusted certificate everywhere. Either
collapses the rule to one mode.
