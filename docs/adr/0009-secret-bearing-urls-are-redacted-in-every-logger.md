# 9. Secret-bearing URLs are redacted in every logger, not just the access log

- Status: accepted

## Chosen

A URI that carries its credential in the path is **redacted, never suppressed**, and the same redaction is rendered into
every logger the edge configures — including the default one behind the site's log block.

## Why

The path **is** the secret: there is no header, cookie or body it could have hidden in. The access log is retained
across rotations, so the credential is written to disk in plaintext and kept.

Suppressing the line is airtight — a line never written cannot leak — and it blinds you: no status, no latency, no
client IP, no evidence when a caller says it delivered and you say it did not. On a route that moves money or grants
access, that blindness is itself a risk. Redaction keeps all of it and removes only the URI.

Redaction has to reach a **path segment**, so it cannot be built on a query-string filter: the credential is not in the
query. The filter used operates on the raw request target, which does reach the path.

The default logger matters because an error attaches the same request object, unfiltered by the site's log block. Any
5xx on a secret-bearing URL therefore writes the raw path into the system journal, and a caller retrying into a down
application is the expected failure, not a hypothetical.

## Cost

**Log treatment is a property of a logger, not of a route.** Two filters cannot attach to the same field, so every
secret-bearing path on a host collapses into one alternation pattern. Adding a path later means editing the pattern, not
setting a per-route flag.

**The pattern is written against the host's real routes and deliberately not spelled out here.** A record is a thing
people copy from, and a copied path list redacts nothing while looking like it does. Whoever authors it verifies it
against a real request.

**A filter that matches nothing fails open.** No error, no changed output — indistinguishable from one that works, so a
wrong or stale pattern writes the credential to disk. So does a misspelled field name, and that one is nastier: field
paths are not validated, so the plausible spelling validates clean and does nothing. Every field name here is
load-bearing and none of them are checked.

**At the version floor, a second filter on the same field silently overwrites the first** and reports a valid
configuration. Alternation is therefore the only form correct across the whole supported range, not a style preference.
A newer version merges them instead, so it will not reproduce the failure.

"Every logger" means every logger the edge configures. An upstream that logs the request path verbatim still writes the
credential in the clear, and closing that is the application's work.

## Reverses

Give up the access log on those routes and suppress instead; or gain per-route log treatment from the server, which
would retire the one-pattern collapse.
