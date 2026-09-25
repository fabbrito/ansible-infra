# 4. Caddy, from the official apt package

- Status: accepted

## Chosen

Caddy, from its own apt repository, rendering a single configuration file. Upgrades ride apt alongside everything else
the OS role upgrades.

Standard modules only. A plugin — a DNS-challenge provider, a firewall — means leaving apt for a self-built binary,
which is a deliberate migration, not a tweak.

## Why

The alternative is nginx plus certbot: a proxy from the distribution, certificates from a second daemon on a timer, and
a reload hook wired alongside. It works, and has for years.

Caddy wins on certificate lifecycle, which is the load-bearing reason and the whole reason the ACME decisions amount to
"Caddy does it" — no second daemon, no renewal timer, no challenge root to wire, no reload hook to forget. Its defaults
are safe where nginx's are a checklist you can silently fail, and a missed item does not announce itself. One structured
log stream folds certificate management in beside the access log, instead of a third format in a third place.

## Cost

Two log streams, and the one that matters is not on disk. A site's log directive configures its access log only;
certificate management goes to the default logger on stderr, which systemd captures. Certificate failures live in the
service journal and nowhere else, and nothing ships them off the host. The role configures the default logger for
redaction of credential-bearing paths and nothing else (ADR-0009).

No certificate-expiry metric. The metrics endpoint covers runtime, middleware and upstream health; expiry alerting needs
an external probe.

Never run the self-upgrade subcommand. It replaces the binary in place, and the next operator-run distribution upgrade
clobbers it. The unattended upgrader will not do it either — Caddy's repository is not a security origin — and that
delay is what makes the clobber a surprise.

## Reverses

Accept a second daemon and a renewal timer. Or take a self-built binary to get a plugin, and give up apt for Caddy.
