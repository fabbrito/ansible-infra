# 9. Secret-bearing URLs are redacted in every logger, not just the access log

- **Status:** accepted
- **Date:** 2026-07-14

## Context

Some public paths carry their credential **in the URL** — a callback a third party posts to, a signed link mailed to a
user. The path _is_ the secret: there is no header, no cookie and no body it could have hidden in instead.

The `caddy` role gives every vhost an access log under `/var/log/caddy/`, rotated and **retained across several files**.
So those secrets are written to disk in plaintext and kept.

Two shapes were on the table, and they are not equivalent. **Suppressing** the log line for those routes is airtight — a
line never written cannot leak — and it blinds you: no status, no latency, no client IP, no evidence when a caller says
it delivered and you say it did not. On a route that moves money or grants access, that blindness is itself a risk.
**Redacting** keeps all of that and removes only the URI — but only if it can reach a **path segment**. Anything that
scrubs the query string is a false sense of safety here, because the secret is not in the query.

Three facts decide it, and two of them are in Caddy's source rather than its documentation:

- **`request>uri` holds path _and_ query, and there is no path-only field.** From `modules/caddyhttp/marshalers.go`:
  `enc.AddString("uri", r.RequestURI)` — Go's raw wire request-target.
- **The `regexp` filter operates on that raw string**, so it does reach the path.
- **The `query` filter provably does not.** `QueryFilter.processQueryString` `url.Parse`s the URI, mutates only
  `u.Query()`, and re-serializes with the path preserved verbatim. A redaction built on `query` would have been exactly
  the false safety we feared.

And one fact that changes the _shape_ of the answer rather than the choice: **Caddy's error logger attaches the same
`request` object, `uri` included** (`caddyhttp/server.go`: `errLog := s.errorLogger.WithLazy(loggableReq)`). It is not
filtered by the site's `log` block, not suppressed by `log_skip`, fires on any handler error, and sinks to stderr —
which means **journald**. Any 5xx on a secret-bearing URL therefore writes the raw path into the system journal, and a
caller retrying into a down app is not a hypothetical: it is the expected failure. It bites harder because
[ADR-0004](0004-caddy-from-the-official-apt-package.md) already establishes the journal as a surface people _read_ —
certificate failures live there and nowhere else, so someone is tailing it during every bring-up.

## Decision

**Redact, never suppress — and render the same filter into every logger the role configures, including Caddy's global
`default` logger.**

```caddy
format filter {
    request>uri regexp "<one alternation over every secret-bearing path>" "${1}REDACTED"
    request>headers>Referer delete
    resp_headers>Location   delete
}
```

The pattern is written **against the host's real routes** and is deliberately not spelled out here — an ADR is a thing
people copy from, and a copied path list redacts nothing while looking like it does. Its shape is an alternation with a
capture, e.g. `^(/a/|/b/)[^/?]+` → `${1}REDACTED`.

**A `regexp` that matches nothing fails open.** It logs no error, changes no output, and is indistinguishable from one
that works — so a wrong or stale path silently writes the credential to disk. Whoever authors the pattern verifies it
against a real request, not by reading it.

**So does a misspelled field name, and that one is nastier.** Caddy does not validate field paths.
`response>headers>Location delete` — the plausible spelling — **validates clean and does nothing**; the correct path is
`resp_headers>Location` (response headers are a _top-level_ log field, not nested under `request`'s sibling). Tested:
both spellings in one config, only the correct one removed the header. There is no error, no warning, and no way to tell
the two apart except by reading the output of a real request. **Every field name in this filter is load-bearing and none
of them are checked.**

This block renders **twice**: once in the site's `log` directive, and once on the default logger in the global options
block. The second one looks redundant and is not — it is the only thing standing between a 5xx on a secret path and that
path landing in journald.

`Referer` and `Location` are deleted because they are the other two fields that can carry the whole URL.

**`log_skip` is the wrong tool and is rejected with suppression**: it drops the _entire_ entry — status, duration,
client IP — which is precisely the blindness we refused to trade for.

No per-path plumbing is needed to make this work. `log` is site-scoped and cannot nest inside `handle` or `route`, but
**a site-level `regexp` is a no-op on a URI that does not match**, so one filter on the vhost redacts the secret routes
and leaves `/` and `/api` untouched.

## Consequences

- **Log treatment is a property of a logger, not of a route.** Caddy's `fields` is a map keyed by field name, so two
  `regexp`s cannot both attach to `request>uri`. Every secret-bearing path on a host must therefore collapse into **one
  alternation pattern**. A route schema cannot express this as a `log: false` boolean hanging off a route, and must not
  pretend otherwise. Adding a secret-bearing path later means editing one pattern, not setting a per-route flag.

  **And at the 2.8.0 floor the failure is silent, which is worse than this bullet implied.** Tested against the real
  binaries: on **2.8.x**, a second `regexp` on the same field **overwrites the first** — the adapter emits one filter,
  keeps the _last_, reports "Valid configuration", and warns about nothing. So the pattern that got dropped is a
  credential written to disk in the clear, and the config that did it looks correct. (2.11+ auto-merges both into
  `multi_regexp` and errors on the mixed cases, so a reader on a newer Caddy will not be able to reproduce this. Do not
  let that convince them it never happened.) **Alternation is therefore not a style preference — it is the only form
  correct across the whole supported range, from the 2.8.0 floor up.**

- **[ADR-0004](0004-caddy-from-the-official-apt-package.md) is amended.** Its statement that the `default` logger is one
  "the role does not configure" was true when written and is now false. The role configures it — for this, and only for
  this.
- **`multi_regexp` would lift the one-filter-per-field limit. We do not use it.** It is undocumented and needs 2.11+.
  Alternation needs nothing beyond the **2.8.0** floor
  [ADR-0008](0008-cloudflare-trust-is-derived-and-client-ip-parsing-is-strict.md) already sets.
- **The error-log leak is REPRODUCED. It was a reading of `server.go`; it is now a measurement.** A live Caddy, a
  `reverse_proxy` to a dead port, a `format filter` on the site redacting the secret path — and a request to it
  produced, in one run:

  ```
  "logger":"http.log.error.log0"   ... "uri":"/secret/TOKEN123"    <- raw. leaked.
  "logger":"http.log.access.log0"  ... "uri":"/secret/REDACTED"    <- filtered.
  ```

  `log_skip` does not save it either: the skipped path emitted **no access entry and still emitted the error entry, with
  the token in clear**. Moving the filter to the global `default` logger fixed it — the same 502 then logged
  `/secret/REDACTED` on `http.log.error`. So the second filter is not defensive over-rendering; **it is the only thing
  between a 5xx on a secret path and journald.** The bring-up check survives as a check, not as the proof — the proof is
  here.

- **Retry behaviour does not change the treatment.** Under _suppression_ it would: going blind on a path nothing retries
  is a different bet from going blind on one that does, so a retried-and-reconciled callback and a one-shot signed link
  would need different answers. Under redaction both keep status, latency and client IP and lose only the URI, so the
  asymmetry buys nothing and every secret-bearing route is treated alike.
- **The access log stays worth having, which was the entire point.** On a secret-bearing route — the one you read on the
  worst day — status, duration and `{client_ip}` all survive.
- **"Every logger" means every logger _the edge configures_. The upstream still writes the secret in the clear, and this
  ADR does not fix that.** A request logger that emits the request path verbatim — the default almost everywhere — puts
  the credential in the application's own logs no matter how well Caddy behaves.

  This is not a gap in the decision: the edge is the only thing this layer controls, and redacting there is still
  necessary. It is a gap in what a reader will _assume_ the decision bought them. **Closing it is the application's
  work**, and until it lands, "the secrets are out of the logs" is false — they are out of _Caddy's_ logs.
