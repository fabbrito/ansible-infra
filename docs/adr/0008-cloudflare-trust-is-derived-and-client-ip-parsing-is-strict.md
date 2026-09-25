# 8. Cloudflare trust is derived from the route, and client-IP parsing is strict

- Status: accepted

## Chosen

A host trusts Cloudflare only where Cloudflare actually fronts it, and the client IP is parsed structurally rather than
positionally.

1. **The trust block is derived, not asserted.** It renders only when at least one route on the host is proxied, and
   that condition is read from the route list — never from a hand-set flag, which could disagree with reality.
2. **Where it renders, parsing is strict and the header list is one entry** — the header Cloudflare overwrites itself,
   so a client cannot forge it.
3. **Every client-IP header forwarded upstream carries the resolved client IP.** There is no single contract header,
   deliberately.
4. **The forwarded protocol header is not asserted.** It is derived from the connection.

## Why

The trusted range is not a hint: it is the entire security boundary, and everything downstream inherits what it decides.
Anything keying on client IP — a rate limiter, an audit log, an allowlist — reads the result as fact.

Non-strict parsing walks the header list and takes the first parseable value. Cloudflare appends the true client IP to
whatever the client sent, so on that path the leftmost value is client-controlled. The previous configuration was safe
only by list order: invisible, unenforced, one well-meant edit from gone. Strict parsing reads from the far end and
stays correct by construction if a header is added back or a second proxy enters the path.

Trust is also server-level, shared by every name on the same listener, so it cannot be scoped to one route. Trusting
unconditionally therefore opens the boundary on hosts no proxy fronts — where anyone may point their own account's zone
at the host's address and arrive as a trusted peer.

Forwarding every client-IP header, rather than one, is not decoration: the overwrite is what destroys the
client-supplied value. Narrowing to one header would forward the others verbatim, which is a hole, not a simplification.

## Cost

The route schema must let a route name who fronts it, and TLS mode must not be the discriminator: a proxied name can
still answer the HTTP challenge, so fusing the two renders no trust block for a proxied ACME route — silently.

Overwriting the forwarded client-IP header must survive on hosts with no proxy. It reads as dead cruft and is not:
without it the client's own header reaches the upstream verbatim — one bucket for the entire internet, with no error and
no log line.

A mixed host trusts the proxy on its direct routes too. Not closable in configuration, which is why decisions 2 to 4
hold independently of decision 1.

On the proxied path, upstreams may now see the visitor's scheme rather than a hardcoded one. That is the truth, and an
application keying on it sees a case it did not before.

The strict option sets a floor on the installed server version; below it the host fails to start rather than silently
ignoring the option. A second proxy provider is a configuration change; two providers on one host are not possible — the
address ranges could union, the header list cannot.

## Reverses

Stop sitting behind the proxy and drop the trust boundary; or gain per-route trust in the server, which it does not
offer.
