# Security policy

## Reporting a vulnerability

Report privately, not as a public issue: use GitHub's **Report a vulnerability** button under this repo's Security tab.
That channel is private until a fix is published, and it is the only one — there is no mailbox to fall back to. Expect
an acknowledgement within a week.

Please do not include anything from the fleet you found it on — a hostname, an address, a certificate, a log line with a
URI in it. Describe the role, the variables involved, and what converged wrong. This repo holds no secrets and no host
data by design, and a report is not an exception to that.

## What is in scope

This collection converges hosts. A finding is in scope when a documented use of a role leaves a host less safe than the
role claims. The recurring shapes:

- **A default that is unsafe to inherit.** Roles default to empty and then skip or assert; a default that carries a real
  value someone else's fleet would silently adopt is a bug even if it is safe for one fleet.
- **A rendered secret reaching the play output.** Every task that renders one carries `no_log: true`. A path that
  bypasses it — a diff, a loop label, a failed assert's message — is a vulnerability, because it lands in the consumer's
  CI logs.
- **A converge that can lock the operator out**, or that opens ingress before the thing guarding it exists.
- **A trust boundary that renders wrong from valid input** — proxy trust derived from an untrusted source, an
  authenticated service answering unauthenticated, a redaction filter that does not fire.

Out of scope: vulnerabilities in the upstream packages these roles install (report those upstream), and the security of
a consuming repo's inventory, vault, or CI — none of which lives here.

## Supported versions

The most recent tag only. Consumers pin a tag, so a fix ships as a new tag they adopt deliberately; there are no
backports to older ones and no branch to track. A released tag is never repointed — if a fix has to reach you, it
reaches you as a version you can see in your own `requirements.yml` diff.
