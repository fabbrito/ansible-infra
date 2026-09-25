# Backup encryption (fleet-wide r2crypt)

Client-side encryption of backups using rclone's `crypt` overlay, so R2 only ever stores ciphertext. The design decision
is [ADR-0007](../adr/0007-backups-to-r2-through-rclone.md); this is the runbook.

> [!NOTE] **Nothing writes through the wrapper yet — this is the runbook for turning it on.** Services that back up
> write to the plain `r2:` remote, because **encryption is deferred**: there is no safe escrow for the crypt passwords,
> and a crypt remote whose passwords are lost is a backup you cannot restore. When that escrow exists, follow the setup
> below, then point the service's `*_r2_dest` vars at `r2crypt:` and delete the old plaintext objects.

## Layout

One fleet-wide key pair wraps the whole `r2:backups` bucket. A service opts in by pointing its destination at `r2crypt:`
instead of `r2:`. Same key, one escrow chore, one rotation event.

```
r2crypt:<service>/<scope>/     →  r2:backups/<service>/<scope>/<encrypted-filename>
```

Directory names stay plain (`directory_name_encryption = false`), so R2 bucket lifecycle rules that key on a prefix keep
matching. Filenames, contents, and size (within 16 bytes) are encrypted.

The `[r2crypt]` stanza is rendered by `roles/rclone` only when both passwords are set: an optional feature keyed on its
secret ([ADR-0015](../adr/0015-a-declared-role-asserts-its-secrets.md)). Without it a host gets the plain `[r2]` remote,
and a service that references `r2crypt:` there fails loudly with "remote not found". `rclone_crypt_target` names what it
wraps, `r2:backups` by default.

**Exactly one password set fails the converge**, because an empty second password keys the remote differently: a wrapper
whose objects nothing can read back.

## First-time setup

**1. Generate the pair** on your laptop, never on a host. Two independent passwords, each put through `rclone obscure`:

```bash
rclone obscure "<password-1>"
rclone obscure "<password-2>"
```

Keep both plaintexts and both obscured forms. `rclone.conf` consumes the obscured form, but **obscuring is not
encryption** — it is trivially reversible with a static key baked into the rclone binary. `ansible-vault` is what
actually protects these.

**2. Escrow the plaintexts out-of-band.** A sealed envelope, a hardware token, a second password manager — at least one
path that survives losing both the vault master password and your password manager.

**Losing the plaintexts and the vault means every encrypted backup is permanently unreadable.** There is no recovery
path, no escrow service, and no support ticket that fixes it.

**3. Set the obscured pair in the fleet-wide vault** (`ansible-vault edit`, wherever the consumer keeps it):

```yaml
rclone_crypt_password: "<obscured-1>"
rclone_crypt_password2: "<obscured-2>"
```

**4. Re-converge the baseline** against every host that takes backups, to render `rclone.conf`. The consuming repo owns
the invocation.

**5. Prove a round-trip before trusting it.** Take a backup, then confirm the ciphertext is opaque through `r2:` and
readable through `r2crypt:`:

The rendered config is root-only, so host-side invocations need `sudo`:

```bash
sudo rclone ls r2:backups/<service>/<scope>/   # encrypted filenames
sudo rclone ls r2crypt:<service>/<scope>/      # plaintext filenames — proves decrypt works
```

**6. Delete any plaintext written before the cutover.** It is not visible through `r2crypt:`, so list it through `r2:`
and remove it by hand.

## Recovery

- **Lost `rclone.conf`, kept the plaintexts** — re-obscure them and rebuild the stanza. The config is reproducible from
  the passwords.
- **Lost the plaintexts and the vault** — the backups are gone. Permanently. See step 2.

## Rotation

Only on suspected key compromise. There is no in-place rotation: every byte must be decrypted and re-encrypted, because
the key is baked into every object.

1. Generate a new pair, obscure it, escrow it.
2. **Change `roles/rclone` first.** The role renders exactly one `[r2crypt]` stanza over a fixed upstream, with no input
   for a second — so a rotation needs the stanza name and its upstream made renderable, a release, and a pin bump in the
   consumer before any host can hold both. Hand-editing `rclone.conf` on a host is undone by the next converge.
3. Render the second stanza (`[r2crypt_v2]`) over a different upstream path on every host.
4. Per host: `sudo rclone copy r2crypt:<service>/<scope> r2crypt_v2:<service>/<scope>` — this streams decrypt-old →
   encrypt-new client-side. It costs 2× the data in bandwidth, per host.
5. Flip each service's destination to `r2crypt_v2:` and redeploy.
6. Validate a backup **and a restore** through the new path, per service.
7. `sudo rclone purge` the old upstream, then remove the old stanza — another role change and release — and the old
   vault keys.

## Why this shape

- **One fleet-wide key, not one per service.** One envelope to escrow, one rotation event, one mental model. The
  trade-off is blast radius on compromise — accepted, because the consumer's vault master password is already a single
  point of failure for every other secret, so this does not materially widen it.
- **`directory_name_encryption = false`** preserves R2 lifecycle rules that match on prefix. Encrypting directory names
  would force retention to move into rclone.
- **`filename_encryption = standard`** hides filenames, at the cost of a ~143-character limit on the source name (base32
  expansion). Switch to `base64` if that ever bites.
