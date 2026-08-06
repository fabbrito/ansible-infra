# Context

The vocabulary this repo uses, and what each word means _here_. It is a glossary and nothing else — the mechanics live
in the roles, the reasoning in `docs/adr/`, and the rules an author must uphold in `AGENTS.md`.

Use these words in issues, plans, comments, docs and role names. Where a near-synonym means something else here, the
entry says so.

## The two repos

**Layer**: This collection — the part of a host that every box needs and no box is interesting for. It owns roles and
playbooks, never an inventory, a vault, or a host. _Avoid_: framework, platform

**Consumer**: The repo that installs this layer and holds what it deliberately does not: inventory, secrets, service
roles, and the converge itself. There is more than one, and none of them may be named here. _Avoid_ as a name for this
repo: client, downstream, controller — "client" also means the authoring team's customer, and "downstream" the far side
of the edge, so all three stay legal in those senses.

**Contract**: The vars that cross roles and therefore carry no role prefix. The consumer sets them; this layer only
reads them. Adding one is a breaking change. _Avoid_: global var, shared var

**Pin**: The git tag a consumer resolves this collection at. Upgrades are a chosen act, so a pin never names a branch.
_Avoid_: version, dependency

## Hosts and fleets

**Fleet**: The set of hosts one consumer converges. This layer never sees one; it makes promises that hold across all of
them.

**Host**: A long-lived Ubuntu VPS, reachable only over the network — there is no console we control. _Avoid_: server,
machine, instance

**Operator**: The human running a converge and reading its output at 3am. Usually someone we have never met. _Avoid_:
user, admin

**Deploy user**: The unprivileged account Ansible connects as and services run under. Created by `bootstrap`, never
defaulted.

**Break-glass**: The root-over-provider-key path that stays open as the last way back into a misconfigured host.
_Avoid_: emergency access, recovery mode

## Converging

**Converge**: One run of a play against a host, driving it to its declared end state. _Avoid_: deploy, provision
(deploying a service is the consumer's word for its own roles)

**Converged end state**: A host that is correct and finished — including one that skipped work whose secret was absent.
Skipped is not degraded. _Avoid_: partial, degraded

**Baseline**: The ordered set of roles every host gets. The order is load-bearing, not stylistic.

**Group-scoped role**: A role deliberately outside the baseline, which a host runs iff its inventory puts it in that
group. One line of inventory instead of a conditional inside a role. _Avoid_: optional role, conditional role

**Load-bearing**: Of an order, a field name, a default: change it and something breaks silently, elsewhere. Marks the
places where "it reads better this way" is a bug report. _Avoid_: important, critical

**Lock-out**: Losing the SSH path to a host — a converge severing Ansible's own connection, which does not fail loudly
(the task succeeds and the box is gone), or the host's own defences banning the operator. Both are guarded ahead of
time, not recovered from. _Avoid_: outage, bricking

## The gate

**Gate**: The three checks that stand between a change and a converged fleet, in increasing order of truthfulness. Only
the first runs here. _Avoid_: test suite, CI (there is no suite; naming one oversells it)

**Dry-run**: A check-mode converge against a real host, read for its diff. Not proof, because check mode lies where a
prerequisite was never really installed — but an unexpected diff is always real. _Avoid_: simulation, preview

**Second converge**: Running the play twice and requiring the second run to report zero changed. The closest thing to a
real test that exists here.

**Changed-every-run**: A task that reports changed on every converge. A bug even when the host ends up correct, because
real drift then hides in the noise. _Avoid_: noisy, non-idempotent

**Precondition**: An invariant a role depends on that the variable schema cannot make unrepresentable, and that fails
silently if unguarded. Roles assert these and nothing else — never that a package installed. _Avoid_: check, outcome
(ADR-0010 uses "validate" for the act; the noun for the thing asserted is precondition)

## Secrets and absence

**Absent-secret skip**: The default behaviour: a role missing its secret does less, quietly, and still converges. It is
what lets a host join a fleet before its secrets exist. _Avoid_: graceful degradation, fallback

**Assert instead of skip**: The exception, taken where absence leaves nothing to do or leaves the host unsafe. A role
choosing it says why, in place.

**Silent skip**: The cost of the rule — a misspelled secret key is indistinguishable from an absent one, and a skipped
task you expected to run is the only signal.

## The edge

**Edge**: The host's TLS front door — the single Caddy instance every route terminates at. What it configures is the
boundary of what this layer controls; an upstream's own logging and trust are not it.

**Route**: One entry in the effective route list: a name, its TLS mode, and the handlers behind it. The unit the edge
config is rendered from, and the unit host-wide trust is derived from. _Avoid_: site, site block, vhost (a site block
carries one TLS directive; a route is the input that may not assume one)

**Effective route list**: The union of the group-level routes and the host-level appends, resolved once; every
derivation reads it and nothing else.

**Upstream**: A backend a route hands a request to. _Avoid_: backend, origin (an origin certificate is a different
thing)

**Catch-all**: The named upstream a route falls back to when no path matches. Named rather than inferred, so two
catch-alls and zero catch-alls are both unrepresentable. _Avoid_: default, fallback route

**TLS mode**: A per-route property, decided by one question with an unambiguous answer: **whose zone is it?** A zone the
operator holds and proxies gets an origin certificate; a zone they do not hold gets ACME. Both modes are permanent.
_Avoid_: cert type, TLS strategy

**Origin certificate**: The certificate an origin presents behind a proxied zone. Not publicly trusted — valid only
because the proxy terminates in front of it. _Avoid_: self-signed, internal cert

**Fronting**: What a proxy provider does to a route it sits in front of. A route declares who fronts it; nothing infers
it from the TLS mode, because the two correlate by policy rather than by law. _Avoid_: proxying (ambiguous — the edge
also proxies to upstreams)

**Trust boundary**: The range of peers whose client-IP headers the edge will believe. Not a hint: outside it those
headers are never read, and inside it everything downstream inherits whatever it decides. It is host-wide, so one
fronted route puts every other route on the box inside it. _Avoid_: allowlist, trusted IPs

**Secret-bearing path**: A public path whose credential is in the URL — a third-party callback, a signed link. The path
_is_ the secret; there is no header or body it could have hidden in. _Avoid_: sensitive route, private endpoint

**Redaction**: Removing the URI from a log line while keeping status, latency and client IP. Chosen over suppressing the
line, which is airtight and blinds you on exactly the route you read on the worst day. _Avoid_: filtering, masking,
scrubbing

## Backups

**Remote**: A named rclone destination. The baseline installs rclone on every host and renders the remote only where the
R2 credentials exist. Renaming it is a breaking change consumers' backup roles feel, because they address it by name.

**Crypt wrapper**: The optional encryption layer over the backups remote, which services opt into by pointing at it
instead. Lose its passwords and the backups are unrecoverable — no escrow, no support ticket. _Avoid_: encrypted remote

## Monitoring

**Hub**: The Beszel web UI a monitoring host runs, bound to loopback. An admin-less hub answers to whoever reaches it,
which is why its admin identity is asserted rather than skipped. _Avoid_ for the hub alone: dashboard, server — a
monitoring host binds two, so "the dashboards" for the pair is correct and "the dashboard" names neither.

**Dozzle**: The log viewer the monitoring stack ships beside the hub, loopback-bound and with no authentication at all.

**Agent**: The metrics collector a monitored host runs, paired to a hub. Where this repo means the software kind, it
says _AI agent_ or points at `docs/agents/`.

**Paired**: Of a host, that its agent holds credentials the hub minted for it. A box converges unpaired and stays
correct. _Avoid_: registered, enrolled
