# fabbrito.infra

Composable roles that converge long-lived Debian-family hosts — cloud VMs and single-board computers, x86 and ARM — as
an Ansible collection.

It installs and keeps converged the parts of a host no host is interesting for: OS settings and unattended upgrades, SSH
hardening, a deny-by-default firewall, fail2ban, Docker with a pruning timer, rclone against Cloudflare R2, Caddy as the
TLS edge, a loopback-bound metrics/logs stack, and, for boards, a fixed LAN address and the journal on a storage volume.
**Service roles do not live here** — they stay in the repo that owns the service, which is also where inventory, secrets
and the converge itself live.

## Platforms

| Distribution    | Releases         | Arch                | Status            |
| --------------- | ---------------- | ------------------- | ----------------- |
| Ubuntu          | 24.04 and later  | amd64, arm64        | Tested            |
| Raspberry Pi OS | Bookworm, Trixie | arm64, armhf        | Tested            |
| Debian          | 12 and later     | amd64, arm64, armhf | Claimed, untested |

`preflight` refuses anything else before a role changes the host: another distribution, a release below its floor, or an
ARMv6 board.

## Install

```yaml
# requirements.yml, in the consuming repo
collections:
  - name: git+https://github.com/fabbrito/ansible-infra.git
    type: git
    version: v1.2.3 # a tag, never a branch — see Versioning
```

The repo is public, so `https` needs no credential — which is what makes this installable from a CI runner without
handing it a deploy key. `git+ssh://git@github.com/…` still works if you would rather the fetch go over your existing
key.

Declare where collections live **before** installing, or Ansible will not find what you just installed and the FQCNs
below fail to resolve:

```ini
# ansible.cfg, at the consuming repo's root
[defaults]
collections_path = ansible/collections
```

```bash
ansible-galaxy collection install -r requirements.yml
```

`collections_path` **replaces** the default search list rather than extending it, so `~/.ansible/collections` and
`/usr/share/ansible/collections` drop out. For a controller that declares every collection in its own `requirements.yml`
that is the point: what resolves is what you pinned, not whatever the operator happens to have at home. It also makes
the install path implicit — pass `-p` instead and `ansible-galaxy` will warn that the target is outside the configured
paths, which is the warning worth not ignoring.

## Use

```yaml
# playbooks/site.yml, in the consuming repo
- name: Every host
  hosts: all
  become: true
  roles:
    - { role: fabbrito.infra.preflight, tags: [preflight] }
    - { role: fabbrito.infra.os, tags: [os] }
    - { role: fabbrito.infra.sshd, tags: [sshd] }
    - { role: fabbrito.infra.firewall, tags: [firewall] }
    - { role: fabbrito.infra.fail2ban, tags: [fail2ban] }

- name: Backups
  hosts: backup_hosts
  become: true
  roles:
    - { role: fabbrito.infra.rclone, tags: [rclone] }

- name: Caddy reverse proxy
  hosts: caddy_hosts
  become: true
  roles:
    - { role: fabbrito.infra.caddy, tags: [caddy] }

- name: My own service
  hosts: my_service_hosts
  become: true
  roles:
    - { role: my_service, tags: [my_service] }
```

There is no fixed baseline: the consumer composes the roles each group runs, and every role asserts what it needs from
the host and its vars. Keep the order `preflight`, `os`, `sshd`, `firewall`, `fail2ban`, then the rest — `firewall`
reads the ports from the effective sshd config, and `fail2ban` bans through ufw. Scope a run with `-l <host>`.

| Role         | Hosts        | What it converges                                                      |
| ------------ | ------------ | ---------------------------------------------------------------------- |
| `preflight`  | every        | Nothing: refuses an unsupported or unready host before any role runs.  |
| `os`         | every        | Packages, unattended upgrades, timezone, NTP, opt-in swap, hostname.   |
| `sshd`       | every        | Key-only SSH, validated before the reload and read back after.         |
| `firewall`   | every        | ufw deny-by-default, declared ingress, a rate limit on the sshd ports. |
| `fail2ban`   | where wanted | sshd and recidive jails, banning through ufw.                          |
| `docker`     | where wanted | Docker engine and compose, an optional registry login, a weekly prune. |
| `rclone`     | backup hosts | Pinned rclone and the R2 remote, with an optional crypt wrapper.       |
| `caddy`      | edge hosts   | Caddy as the TLS edge for the consumer's routes.                       |
| `monitoring` | where wanted | Beszel hub and agent, Dozzle, loopback-bound.                          |
| `tailscale`  | where wanted | The host on a tailnet, additive to its own SSH path.                   |
| `network`    | boards       | A fixed LAN address beside DHCP, through NetworkManager.               |
| `journal`    | boards       | The journal bind-mounted onto a storage volume.                        |

`journal`, `network`, `seed` and `tailscale` ship a playbook each (`fabbrito.infra.<role>`) for consumers that import
rather than compose.

`bootstrap` and `update` ship too: `fabbrito.infra.bootstrap` creates the unprivileged deploy user on a fresh box (run
once, as root), `fabbrito.infra.update` does a serial apt upgrade with a reboot when required.

`seed` is the cloud-init alternative to `bootstrap`, for a board's boot partition or a provider's user-data field: it
renders a seed that creates `deploy_user` with `deploy_authorized_keys`, key-only, with passwordless sudo. On a `vm` the
provider's default user stays as break-glass; on a `board` bumping `seed_generation` re-applies the seed on next boot.

```bash
ansible-playbook fabbrito.infra.bootstrap -e target=<host>   # -e, NOT -l
ansible-playbook fabbrito.infra.update -l <host-or-group>
ansible-playbook fabbrito.infra.seed -e target=<host> -e seed_output_dir=<dir>
```

`bootstrap` is the one play addressed by `-e target=`. Omit it and the play matches a sentinel group that exists in no
inventory: zero hosts, a host-pattern warning, and **exit 0** — a green run that created nothing. That is deliberate, so
a forgotten flag cannot fan user-creation and sudoers writes across the whole fleet, but it only protects you if you
know the flag is there.

A role runs on a host iff the consumer's plays put the host in a group that lists it: one line of inventory rather than
a conditional inside a role.

## What the consumer must provide

A collection cannot ship `group_vars`, so the vars that cross roles are a contract rather than a default. Set them in
the consuming repo's inventory. Nothing here is optional-by-accident: where a value is absent the role either fails
loudly or, for an optional feature keyed on it, skips that feature — which one is stated below.

**Required to converge anything**

| Var           | Where                       | What it buys                                                                                                         |
| ------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `deploy_user` | `group_vars/all`            | The unprivileged account Ansible connects as and services run under.                                                 |
| `host_kind`   | `group_vars` or `host_vars` | `board` or `vm`. Asserted by `preflight`; `board` also needs `/proc/device-tree/model`. Board-only checks key on it. |

**Required by `bootstrap`**

| Var                      | Where                  | What it buys                                                                                                                                                                                                                   |
| ------------------------ | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `deploy_authorized_keys` | `group_vars/all/vault` | The pubkeys authorized for `deploy_user`. Unset or empty → `bootstrap` refuses before it creates anything. Empty is why it asserts: the list installs no key, yet the play would still grant passwordless sudo and exit green. |
| `deploy_user`            | `group_vars/all`       | Asserted here too — `bootstrap` creates this account, so it cannot be defaulted.                                                                                                                                               |

**Optional — absent, the feature it keys is off**

| Var                                                | Effect when absent                                                                                                                                                                                            |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ghcr_pull_token`                                  | `docker` is plain Docker, with no registry login.                                                                                                                                                             |
| `ghcr_login_username`                              | Required whenever the token is set — asserted.                                                                                                                                                                |
| `rclone_crypt_password` + `rclone_crypt_password2` | No `r2crypt` wrapper is rendered and backups write to the plain remote. Both or neither — asserted. See docs/rclone/encryption.md.                                                                            |
| `os_hostname_domain`                               | `os` does not name the box at all — the provider's name stands. Set it, and the box becomes `<inventory key>.<domain>`. Override the derivation per host with `os_hostname`; naming happens if either is set. |

**Required once a host joins the group that needs it**

| Var                                                          | Group            | Effect when absent                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------------ | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rclone_r2_access_key_id`, `_secret_access_key`, `_endpoint` | backup hosts     | Asserted by `rclone`.                                                                                                                                                                                                                                                                                                       |
| `caddy_acme_email`                                           | caddy hosts      | Asserted, but only if a route uses `tls: acme`.                                                                                                                                                                                                                                                                             |
| `caddy_routes`                                               | caddy hosts      | Defaults to `[]` — a live proxy answering nothing. Join the group in the same change that gives it routes.                                                                                                                                                                                                                  |
| `caddy_origin_cert` / `caddy_origin_key`                     | caddy hosts      | Asserted before anything is installed: every `tls: cert` route needs both halves of the cert it names (these for `default`, a `caddy_extra_certs` entry otherwise).                                                                                                                                                         |
| `monitoring_admin_email` + `monitoring_admin_password`       | monitoring hosts | Asserted. Without them the hub creates no first user and answers unauthenticated.                                                                                                                                                                                                                                           |
| `monitoring_agent_key` + `monitoring_agent_token`            | monitoring hosts | Minted together by the hub (see docs/monitoring/access.md). No token → the agent is not rendered, and hub and Dozzle still come up, so a box can join before it is paired. Token without key → asserted, since it would start an agent that can never authenticate. Key without token is fine: it is the documented revoke. |
| `network_address`                                            | network hosts    | A board's fixed LAN address, CIDR. `network` asserts it, `host_kind: board` and NetworkManager, and keeps DHCP beside it.                                                                                                                                                                                                   |
| `tailscale_auth_key`                                         | tailscale hosts  | Asserted. Read only while the host is off the tailnet; a host an operator took down with `tailscale down` stays down.                                                                                                                                                                                                       |
| `storage_path`                                               | journal hosts    | The storage volume's mount path. `journal` asserts it absolute and mounted before binding `/var/log/journal` onto it; board runbook in docs/storage/persistent-usb-storage.md.                                                                                                                                              |
| `infra_install_dir`                                          | monitoring hosts | Where the role installs the stack tree. Undefined-variable failure when `monitoring` creates its directory. A contract var, so it carries no role prefix.                                                                                                                                                                   |

Every role's own vars are documented in its `defaults/main.yml`, which is the role's public API — read it before
overriding anything.

## Where the gate lives

This repo can only prove the static half, and it splits by cost. `make check` is the fast leg — formatting, playbook
syntax, `ansible-lint` at the **production** profile and `shellcheck` — and the pre-commit hook runs it on every commit.
`make sanity` is `ansible-test sanity`; it builds a venv per supported Python on first run, so it stays out of `check`.
`make test` renders the templates against checked-in fixtures and diffs the bytes. There is no CI (ADR-0013):
`make release` runs `sanity`, `test` and the collection build before it tags.

That last one exists because linting and validating both stop short of the same thing. `ansible-lint` reads the tasks
and `caddy validate` reads the syntax; neither can see a config that is _valid_ and says the wrong thing — a proxy-trust
block on a host nothing fronts, a body cap silently clamped by a matcher-less default, a redaction filter naming a
prefix that never occurs. Asserts check what the consumer sets; goldens check what we emit.

The half that matters most is not provable here, because this repo has no inventory and reaches no host:

- a `--check --diff` dry-run against a real box, and reading the diff
- a **second converge** reporting zero changed

Both belong to the consuming repo, and a version bump is not adopted until they pass there. A role that is
changed-every-run is a bug even when the host ends up correct.

## Versioning

The collection version in `galaxy.yml` and the git tag move together, and consumers pin the tag. Upgrades are a chosen
act: bump the pin, re-run the consumer's gate, then converge. Nothing here auto-updates, and `version:` pointing at a
branch defeats the whole arrangement.

Dependencies are pinned to majors in `galaxy.yml`, and the `ansible-core` floor lives in `meta/runtime.yml`, enforced at
install time.

## Development

```bash
make deps    # install the collections the roles depend on
make hooks   # enable the repo's git hooks — once per clone
make fmt     # prettier + shfmt
make check   # every hook lane — must be green to commit
make sanity  # ansible-test sanity — a release leg; slow on a cold venv
make test    # golden render tests — a release leg
make release VERSION=x.y.z  # stamp, gate on every leg, tag; DRY_RUN=1 to rehearse
```

How to work in this repo, for people and agents alike: `AGENTS.md`.

## Security

Report a vulnerability privately — see [SECURITY.md](SECURITY.md) for the channel and for what counts as one here.

## License

Apache-2.0. See [LICENSE](LICENSE).
