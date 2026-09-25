# 7. Backups to R2 through rclone, with a crypt wrapper

- Status: accepted

## Chosen

Offsite backups go to R2, reached through rclone, with bucket-scoped API tokens. The role renders an S3 remote plus an
optional fleet-wide crypt wrapper over the backups bucket; a service opts into encryption by pointing at the wrapped
remote instead of the plain one.

A bucket is scoped per project, not per host, and its token lives in the vault of the group that shares it.

## Why

Per-host buckets were the obvious alternative and lose: a second host serving the same service would need its own bucket
and its own copy of the credentials, which turns scaling a service into a credential-provisioning task.

Bucket-scoped tokens are the least-privilege choice, and they are the source of every non-obvious setting on the remote.
Two of them look like mistakes until you know they are forced: a bucket-scoped token cannot do what the client assumes
it can, so the per-upload permission header and the pre-flight bucket check both come back denied and are both turned
off.

The crypt wrapper leaves directory names unencrypted so the tree stays readable to the provider and its lifecycle prefix
rules still match. File names and contents are still encrypted.

## Cost

**Lose the crypt passwords and the backups are unrecoverable.** There is no escrow and no support path that fixes it.
They belong in a password manager, not only in the vault.

**The remote name is fixed.** A consumer's backup roles reference it by that name, and this layer ships none of them, so
renaming it means changing every one of them in lockstep.

The credentials are a precondition: a host that lists the role without them fails the converge naming the key
(ADR-0015).

## Reverses

A different object store, or per-host buckets once credential provisioning is cheap. Neither touches the crypt decision,
which is independent.
