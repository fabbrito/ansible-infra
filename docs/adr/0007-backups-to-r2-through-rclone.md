# 7. Backups to R2 through rclone, with a crypt wrapper

- **Status:** accepted
- **Date:** 2026-07-13

## Context

Service backups need offsite storage. We use **Cloudflare R2** with **bucket-scoped API tokens**, reached through
**rclone**, which the baseline installs on every host.

Bucket-scoped tokens are the least-privilege choice, and they are also the source of every non-obvious setting below. A
token scoped to one bucket cannot do things rclone assumes it can.

## Decision

An `r2` S3 remote, plus an optional fleet-wide `r2crypt` **crypt wrapper** over the backups bucket. Services opt into
encryption by pointing their destination at `r2crypt:` instead of `r2:`.

**A bucket is scoped per project, not per host**, and its token lives in the vault of the group that shares it. Per-host
buckets were the obvious alternative and lose: a second box serving the same service would need its own bucket and its
own copy of the credentials, which makes scaling a service a credential-provisioning task. This is the decision the
hardening runbook and the role's defaults both follow.

Two settings on the R2 remote are forced by the scoped token, and both look like mistakes until you know why:

- **No `acl = private`.** R2's "Object Read & Write" tokens deny `PutObjectAcl`, so rclone's per-PUT
  `x-amz-acl: private` header comes back as a 403.
- **`no_check_bucket = true`.** Bucket-scoped tokens lack the list-buckets permission, so rclone's pre-flight `HEAD` on
  the bucket 403s too.

The crypt wrapper sets `directory_name_encryption = false`, so the directory tree stays readable to R2 and bucket
lifecycle prefix rules still match. Filenames and contents are still encrypted.

## Consequences

- **Lose the crypt passwords and the backups are unrecoverable.** There is no recovery path, no escrow, and no support
  ticket that fixes it. They belong in a password manager, not only in the vault.
- **The remote name `r2` is hardcoded.** A consumer's backup roles reference `r2:bucket/...` by that name; this layer
  ships none of them. Renaming it means changing every one of them in lockstep.
- Per [ADR-0001](0001-secrets-in-vault-and-an-absent-secret-skips.md), a host without R2 credentials still converges:
  rclone is installed, and no config is rendered.
