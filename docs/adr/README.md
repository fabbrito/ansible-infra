# Architecture decision records

Each record is one decision that shaped a role: what was chosen, what it cost, and what would have to change for the
choice to stop being right. Read the ones covering a role before overriding its defaults — several of those vars only
make sense as the consequence of a decision recorded here.

| ADR                                                                         | What it settles                                                              |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| [0002](0002-a-converge-can-never-lock-us-out.md)                            | Ordering rules that keep a converge from severing its own connection.        |
| [0003](0003-the-gate-is-static-checks-and-a-second-converge.md)             | There is no unit suite; the gate is static checks plus a second converge.    |
| [0004](0004-caddy-from-the-official-apt-package.md)                         | Caddy comes from the upstream apt repo, and `caddy upgrade` is forbidden.    |
| [0005](0005-tls-mode-follows-dns-zone-ownership.md)                         | A route's TLS mode follows who holds the DNS zone.                           |
| [0006](0006-http-01-forced-and-the-ca-unpinned.md)                          | HTTP-01 only, no DNS-01, and the issuing CA is left unpinned.                |
| [0007](0007-backups-to-r2-through-rclone.md)                                | Backups go to Cloudflare R2 through rclone.                                  |
| [0008](0008-cloudflare-trust-is-derived-and-client-ip-parsing-is-strict.md) | Proxy trust is derived from the route, and client-IP parsing is strict.      |
| [0009](0009-secret-bearing-urls-are-redacted-in-every-logger.md)            | Secret-bearing URIs are redacted — never suppressed — in every logger.       |
| [0011](0011-distribution-is-a-git-tag-not-a-galaxy-publish.md)              | Consumers pin a git tag; there is no Galaxy publish.                         |
| [0013](0013-there-is-no-ci.md)                                              | There is no CI; hooks gate commits, the maintainer PRs, release the tag.     |
| [0014](0014-roles-assert-pre-and-postconditions.md)                         | Roles assert preconditions and cheap postconditions, from host state.        |
| [0015](0015-a-declared-role-asserts-its-secrets.md)                         | A declared role asserts its secrets; optional features are keyed on theirs.  |
| [0016](0016-consumers-compose-the-roles.md)                                 | Consumers compose the roles; no fixed set, no meta dependencies.             |
| [0017](0017-hosts-are-debian-family-vms-or-boards.md)                       | Debian-family hosts, declared VM or board; userland arch; ARMv6 refused.     |
| [0018](0018-the-seed-creates-the-deploy-user.md)                            | A cloud-init seed creates the deploy user; on a board it is the break-glass. |
| [0019](0019-unattended-upgrades-is-the-only-scheduled-upgrader.md)          | Unattended-upgrades is the only scheduled upgrader and rebooter.             |
| [0020](0020-storage-is-a-runbook-and-the-journal-a-bind-mount.md)           | Storage is a runbook; the journal moves by bind mount.                       |
| [0021](0021-tailscale-from-its-own-apt-repo.md)                             | Tailscale from its own apt repo, joined by a required key.                   |

Each of these explains either a role or the collection itself — how it is gated (0003), how it validates (0014), how it
reaches a consumer (0011), and who runs the gate now that nothing runs on a push (0013). Decisions about running a fleet
— how inventory expresses service composition, which repo owns a host, where a secret sits in a vault — belong to the
consuming repo, which records them itself. An ADR added here meets the same bar.
