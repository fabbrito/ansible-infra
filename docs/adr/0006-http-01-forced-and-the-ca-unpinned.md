# 6. HTTP-01 is forced; the CA is not pinned

- Status: accepted

## Chosen

Control of a name is proven over HTTP-01. It is forced, not preferred.

The issuing authority is left unpinned: the server's default chain, fallback included, accepted knowingly.

## Why

DNS-01 is unavailable to us, not merely unattractive. It needs a challenge record written into the zone, and the names
needing a public certificate are exactly the names whose zone the operator does not hold — that is why they need one.
The alternatives are the third party handing over credentials for their zone, or delegating the challenge name; neither
exists, and neither is unilateral to arrange.

HTTP-01 works for the reason DNS-01 does not: the third party already pointed a record at the host, so the one thing
given is the one thing the challenge needs, on a port already open.

Nothing about the situation forces a choice of authority. Pinning one was considered and declined: the fallback is the
only thing between an upstream outage and an unreachable service, and on a host serving one name, reachability wins.
What we refuse is for the fallback to arrive as a surprise — an account email is what admits it, and its own failures
are silent.

## Cost

**No wildcard certificates on these names, ever** — those are issued only over DNS-01. That keeps the DNS-challenge
plugin out, which is what keeps the apt package sufficient (ADR-0004).

**Port 80 stays open and directly reachable** for renewal, not only first issuance, and a route must not disable
automatic HTTPS, whose vhost answers the challenge. Nothing fails at converge time when it is gone — issuance simply
stops. A firewall change that looks harmless in January breaks certificates in March.

**The account email is required and asserted.** It admits the fallback, so dropping it silently is a different converge,
not a smaller one. It is an address, not a credential.

**Accepted risk.** The third party can re-point the record, and renewal then fails silently two months later, with
nothing shipping the host's journal anywhere and expiry mail being retired. If they front the name with their own proxy,
HTTP-01 breaks and DNS-01 was never there to fall back to.

## Reverses

A second name in a zone the operator does hold, served through a proxy on an origin certificate, removes the ACME
dependency entirely — cheap only while the schema keeps two names for one service cheap (ADR-0005).
