# 8. Cloudflare trust is derived from the route, and client-IP parsing is strict

- **Status:** accepted
- **Date:** 2026-07-14

## Context

Caddy resolves `{client_ip}` from a request header — `CF-Connecting-IP`, `X-Forwarded-For` — but **only when the
immediate TCP peer sits inside a `trusted_proxies` range**. Outside it, the headers are never read and `{client_ip}` is
the peer address. `trusted_proxies` is therefore not a hint: it is the entire security boundary, and everything
downstream inherits whatever it decides. The `caddy` role hands `{client_ip}` upstream, where anything that keys on
client IP — a rate limiter, an audit log, an allowlist — reads it as fact.

Two properties of Caddy's configuration model shape what follows.

**Trust is server-level.** `trusted_proxies` and `client_ip_headers` are options of the `servers` block, scoped only by
listener address. Every vhost shares `:443`. So trust cannot be scoped to one vhost — it is **all-or-nothing per host**,
and the moment one Cloudflare-proxied route exists, every other route on the box is inside the trust boundary too.

**Non-strict parsing walks the header list in config order and takes the first parseable IP, left-to-right.** Cloudflare
_appends_ the true client IP to whatever `X-Forwarded-For` the client sent, so on that path the header arrives as
`<whatever the client wrote>, <the true client IP>` and the left-most value is **client-controlled**.

The role previously wrote, unconditionally on every host:

```
servers {
    trusted_proxies static <cloudflare ranges>
    client_ip_headers CF-Connecting-IP X-Forwarded-For
}
```

Both properties bite here.

- The block renders on hosts Cloudflare does not front. A name in a zone the operator does not own resolves straight to
  the box ([ADR-0005](0005-tls-mode-follows-dns-zone-ownership.md)), so no legitimate request ever arrives from a
  Cloudflare address — but anyone may point **their own** Cloudflare zone at this host's IP, and their requests then
  arrive from a trusted peer. Trust with no traffic behind it is pure attack surface.
- Listing `X-Forwarded-For` re-admits the client-controlled value. We were saved only because `CF-Connecting-IP` is
  listed **first** and Cloudflare always sets it, so it wins on precedence. The configuration was safe by **list order**
  — invisible, unenforced, and one well-meant edit from gone.

Caddy's own `reverse_proxy` documentation warns about exactly this: _"If you're using Cloudflare in front of Caddy, be
aware that you may be vulnerable to spoofing of the `X-Forwarded-For` header."_

## Decision

**A host trusts Cloudflare only where Cloudflare actually fronts it, and the client IP is parsed structurally rather
than positionally.**

**1. The trust block is derived, not asserted.** The `servers` block renders only when at least one route on the host is
Cloudflare-proxied, and that condition is read **from the route list** — never from a separate hand-set flag, which
could disagree with reality. A host with no Cloudflare-proxied route renders no `servers` block, and its `{client_ip}`
is always the true TCP peer.

**2. Where it renders, parsing is strict and the header list is one entry:**

```
servers {
    trusted_proxies static <cloudflare ranges>
    trusted_proxies_strict
    client_ip_headers CF-Connecting-IP
}
```

Cloudflare overwrites `CF-Connecting-IP` itself, so a client cannot forge it. Dropping `X-Forwarded-For` closes the
vector; `trusted_proxies_strict` — which parses right-to-left and takes the first value **not** in a trusted range —
means the config stays correct **by construction** if a header is ever added back or a second proxy enters the path,
rather than by an ordering accident.

**3. Every client-IP header we forward upstream carries `{client_ip}`. There is no single contract header,
deliberately.**

```
header_up X-Real-IP        {client_ip}
header_up X-Forwarded-For  {client_ip}
header_up CF-Connecting-IP {client_ip}
```

Bare `header_up` **overwrites**. Each line is not decorating a header — it is **destroying a client-supplied one**.
Narrowing to a single header would forward the other two verbatim from the client, so it is not a simplification: it is
a hole.

**4. `X-Forwarded-Proto` is not asserted.** Caddy derives it from the connection, and honours an incoming value only
from a trusted peer. A hardcoded `header_up X-Forwarded-Proto https` is accurate only while every route is TLS, and lies
silently the moment one is not.

## Consequences

- **Caddy ≥ 2.8.0 is a floor**, which is when `trusted_proxies_strict` appeared. Hosts install the official apt package
  unpinned ([ADR-0004](0004-caddy-from-the-official-apt-package.md)) and track current stable, so this is satisfied with
  room to spare. A host somehow below the floor **fails to start** rather than silently ignoring the option — the
  correct failure mode, and the reason the floor is worth stating rather than discovering.
- **The route schema must let a route name who fronts it**, because the global trust block is derived from that field
  and nothing else. TLS mode is deliberately _not_ the discriminator: a proxied name can still answer HTTP-01, so fusing
  the two into one field renders no trust block for a proxied ACME route — silently. The role's `defaults/main.yml` says
  so at the field.
- **`header_up CF-Connecting-IP {client_ip}` must survive on hosts with no Cloudflare.** On such a box it reads as
  obvious dead cruft. It is not: `header_up` overwrites, so without it the client's own `CF-Connecting-IP` reaches the
  upstream verbatim, and anything keying on client IP then trusts a value the client wrote — **one bucket for the entire
  internet**, with no error, no failing test and no log line. The template says so at the line, because that is the only
  place someone about to delete it will look.
- **A mixed host trusts Cloudflare on its direct routes too.** Trust is server-level and both vhosts share `:443`, so a
  host serving one Cloudflare-proxied name and one direct name has the trust boundary open for both. This is not
  closable in configuration; it is why decisions 2–4 must hold independently of decision 1, and why they are not merely
  defence in depth.
- **On the Cloudflare path, upstreams may now see `X-Forwarded-Proto: http`.** Cloudflare forwards the _visitor's_
  scheme, and we no longer overwrite it. That is the truth, and an application keying on it (secure cookies under
  `trust proxy`) sees a case it never saw before. Cloudflare's _Always Use HTTPS_ and Caddy's own HTTP→HTTPS redirect
  are what keep it to `https` in practice.
- **A second proxy provider is a config change; a second provider _on one host_ is not possible.** The role keys ranges
  and client-IP header by provider, so adding one is a new entry rather than a code change. But a host asserts that at
  most one provider fronts it: ranges could union, `client_ip_headers` cannot.
