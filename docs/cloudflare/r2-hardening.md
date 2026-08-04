# R2 backup hardening

Hardening for the R2 destination that [ADR-0007](../adr/0007-backups-to-r2-through-rclone.md) sets up. Apply it
**after** a plain single-bucket backup flow is working — this is the second pass, not the first.

> [!NOTE] This collection ships no service roles, so nothing here takes a backup on its own — the `rclone` role renders
> the remote and a consumer's service role writes through it. Decide the token model before the first bucket exists, not
> after.

## What R2 forces on us

These are constraints, not preferences — every non-obvious choice below follows from one of them.

- **IAM is bucket-level only.** There are no prefix-scoped tokens.
  ([R2 API tokens](https://developers.cloudflare.com/r2/api/tokens/))
- **There is no write-only token.** Read, or Read+Write. A host that can write its backups can also read them — and
  delete them. ([R2 API tokens](https://developers.cloudflare.com/r2/api/tokens/))
- **Bucket Locks are retroactive**, take precedence over lifecycle rules, and block emptying the bucket while a rule
  exists. Up to 1000 rules per bucket. ([R2 Bucket Locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/))
- Storage is priced by GB-month, not by bucket count, and the account gets 1000 buckets. **A bucket per host is free.**
  ([R2 pricing](https://developers.cloudflare.com/r2/pricing/))

## Threat model

| Threat                                      | Mitigation                                      |
| ------------------------------------------- | ----------------------------------------------- |
| Host A's token leaks → reads B's backups    | Per-host bucket — the token's scope is a bucket |
| Host token leaks → attacker deletes backups | Bucket Lock, retention ≥ backup retention       |
| Operator fat-fingers a delete               | The same Bucket Lock                            |
| Cloudflare account breach                   | Out of scope — needs a second provider          |

The first two are the reason per-host buckets exist. Because there is no write-only token, a compromised host **can**
delete its own backups; the Bucket Lock is the only thing that stops it, which is why it is not optional.

## 1. A bucket per host

Dashboard → R2 → **Create bucket**, named for the host (`infra-<host>`, matching `inventory_hostname`). Leave Object
Lock off — Bucket Locks (§3) are the mechanism.

## 2. A token per host

Dashboard → R2 → **Manage R2 API Tokens** → **Create**:

- Name: `backup-<host>`
- Permissions: **Object Read & Write**
- Buckets: scoped to `infra-<host>` and nothing else
- Client IP filter: optionally the host's egress IP

Into the host's vault:

```yaml
rclone_r2_access_key_id: "<key>"
rclone_r2_secret_access_key: "<secret>"
rclone_r2_endpoint: "https://<account_id>.r2.cloudflarestorage.com"
```

Then re-converge the baseline against the host to re-render `rclone.conf` (the consuming repo owns the invocation).

The bucket-scoped token is also what forces the two settings in `roles/rclone` that look like mistakes — no
`acl = private`, and `no_check_bucket = true`. Both are 403s waiting to happen otherwise;
[ADR-0007](../adr/0007-backups-to-r2-through-rclone.md) explains why.

## 3. Bucket Lock

Set time-based retention to match the service's backup retention. Recent objects become immutable; older ones still age
out normally.

Dashboard → bucket → **Settings → Bucket Lock → Add rule**:

- Name: `retain-30d`
- Apply to: all objects, or a prefix
- Retention: time-based, 30 days

Or:

```bash
wrangler r2 bucket lock add infra-<host> --name retain-30d --retention-days 30
```

**Verify it actually bites** — deleting a recent object must fail:

```bash
ssh <deploy_user>@<host> 'sudo rclone delete r2:infra-<host>/<service>/<recent-object>'
```

An object older than the retention window should still delete. If both succeed, the lock is not doing anything and you
have no ransomware protection.

## 4. Ops

- **Rotate a token** — create the new one, swap it into the vault, re-converge the baseline against the host, then
  revoke the old one.
- **Decommission a host** — revoke the token, remove the lock rule (or wait out the retention), then empty and delete
  the bucket. **Locks block emptying**, so a bucket with a live rule cannot simply be deleted.

## 5. Not implemented

- **A mirror off Cloudflare** (B2, Hetzner). B2 supports genuinely write-only application keys, which is strictly better
  than R2's token model — a host could write backups it cannot read or delete.
- **Alerting on a delete spike or an auth-failure spike.** Nothing watches the bucket today.
