# fabbrito.infra

Baseline convergence for long-lived Ubuntu VPS hosts, as an Ansible collection.

It installs and keeps converged the layer every box needs and no box is interesting for: OS hardening and swap, a
deny-by-default firewall, fail2ban, Docker with a pruning timer, rclone against Cloudflare R2, Caddy as the TLS edge,
and a loopback-bound metrics/logs stack. **Service roles do not live here** — they stay in the repo that owns the
service, which is also where inventory, secrets and the converge itself live.

## Install

```yaml
# requirements.yml, in the consuming repo
collections:
  - name: git+https://github.com/fabbrito/ansible-infra.git
    type: git
    version: v1.2.0 # a tag, never a branch — see Versioning
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
- import_playbook: fabbrito.infra.baseline

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

`baseline` is `hosts: all` and runs `os`, `ufw`, `fail2ban`, `docker`, `rclone` in that order — the order is
load-bearing, not stylistic. Scope a run with `-l <host>`, never by narrowing the play.

`bootstrap` and `update` ship too: `fabbrito.infra.bootstrap` creates the unprivileged deploy user on a fresh box (run
once, as root), `fabbrito.infra.update` does a serial apt upgrade with a reboot when required.

```bash
ansible-playbook fabbrito.infra.bootstrap -e target=<host>   # -e, NOT -l
ansible-playbook fabbrito.infra.update -l <host-or-group>
```

`bootstrap` is the one play addressed by `-e target=`. Omit it and the play matches a sentinel group that exists in no
inventory: zero hosts, a host-pattern warning, and **exit 0** — a green run that created nothing. That is deliberate, so
a forgotten flag cannot fan user-creation and sudoers writes across the whole fleet, but it only protects you if you
know the flag is there.

`caddy` and `monitoring` are deliberately **not** in the baseline. They are group-scoped: a host runs them iff it is in
that group, which is one line of inventory rather than a conditional inside a role.

## What the consumer must provide

A collection cannot ship `group_vars`, so the vars that cross roles are a contract rather than a default. Set them in
the consuming repo's inventory. Nothing here is optional-by-accident: where a value is absent the role either skips its
work or fails loudly, and which one is stated below.

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

**Optional — absent, the role skips that work rather than failing**

| Var                                                          | Effect when absent                                                                                                                                                                                            |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ghcr_pull_token`                                            | `docker` is plain Docker, with no registry login.                                                                                                                                                             |
| `ghcr_login_username`                                        | Required whenever the token is set — asserted.                                                                                                                                                                |
| `rclone_r2_access_key_id`, `_secret_access_key`, `_endpoint` | `rclone` installs the binary, renders no remote named `r2`. All three or none — asserted.                                                                                                                     |
| `rclone_crypt_password` + `rclone_crypt_password2`           | No `r2crypt` wrapper is rendered and backups write to the plain remote. Both or neither — asserted. See docs/rclone/encryption.md.                                                                            |
| `os_hostname_domain`                                         | `os` does not name the box at all — the provider's name stands. Set it, and the box becomes `<inventory key>.<domain>`. Override the derivation per host with `os_hostname`; naming happens if either is set. |

**Required once a host joins the group that needs it**

| Var                                                    | Group            | Effect when absent                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------ | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `caddy_acme_email`                                     | caddy hosts      | Asserted, but only if a route uses `tls: acme`.                                                                                                                                                                                                                                                                             |
| `caddy_routes`                                         | caddy hosts      | Defaults to `[]` — a live proxy answering nothing. Join the group in the same change that gives it routes.                                                                                                                                                                                                                  |
| `caddy_origin_cert` / `caddy_origin_key`               | caddy hosts      | Asserted before anything is installed: every `tls: cert` route needs both halves of the cert it names (these for `default`, a `caddy_extra_certs` entry otherwise).                                                                                                                                                         |
| `monitoring_admin_email` + `monitoring_admin_password` | monitoring hosts | Asserted. Without them the hub creates no first user and answers unauthenticated.                                                                                                                                                                                                                                           |
| `monitoring_agent_key` + `monitoring_agent_token`      | monitoring hosts | Minted together by the hub (see docs/monitoring/access.md). No token → the agent is not rendered, and hub and Dozzle still come up, so a box can join before it is paired. Token without key → asserted, since it would start an agent that can never authenticate. Key without token is fine: it is the documented revoke. |
| `infra_install_dir`                                    | monitoring hosts | Where the role installs the stack tree. Undefined-variable failure when `monitoring` creates its directory. A contract var, so it carries no role prefix.                                                                                                                                                                   |

Every role's own vars are documented in its `defaults/main.yml`, which is the role's public API — read it before
overriding anything.

## Where the gate lives

This repo can only prove the static half, and it splits by cost. `make check` is the fast leg — formatting, playbook
syntax, `ansible-lint` at the **production** profile, `shellcheck`, and that the collection builds — and the pre-commit
hook runs it on every commit. `make sanity` is `ansible-test sanity`, the 34 checks ansible-core ships; it builds a venv
per supported Python on first run, so it stays out of `check`. `make test` renders the templates against checked-in
fixtures and diffs the bytes. CI runs all three.

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
make sanity  # ansible-test sanity — CI runs it; slow on a cold venv
make test    # golden render tests — CI runs it
```

`make check` needs `ansible-lint`, `shellcheck`, `shfmt` and `npx` on top of `ansible-core`; `make deps` installs the
Ansible collections only. A missing tool is a failure, not a skip — a gate that prints green for a leg it never ran is
worse than no gate.

`make sanity` needs nothing extra: `ansible-test` ships with `ansible-core`. It stages a copy of the working tree under
`.collections/`, because `ansible-test` requires its working directory to physically sit inside
`ansible_collections/<ns>/<name>` and resolves symlinks, so the one `make check` stages will not do. `tests/sanity/`
carries one ignore entry, for the shebang on the script `roles/docker` renders onto the host — systemd execs that file
directly, so the shebang is load-bearing rather than a stray.

Bash follows the [YSAP style guide](https://style.ysap.sh); `make fmt` applies the repo's flags (`shfmt -i 0 -ci`). The
scripts under `scripts/` use no `set -e` by policy — errexit hides the failure that matters, and each check records its
own. That policy is about the scripts the gate lints. Scripts this repo _renders onto a host_ are a separate call:
`roles/docker`'s cleanup unit does set errexit, because a systemd oneshot should fail its unit rather than press on.

## Security

Report a vulnerability privately — see [SECURITY.md](SECURITY.md) for the channel and for what counts as one here.

## License

Apache-2.0. See [LICENSE](LICENSE).
