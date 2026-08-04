# Upgrading rclone

We install a **pinned upstream rclone `.deb`**, not the distro package. This is the procedure to move the pin — the only
way rclone changes version on the fleet.

## Why pinned, and why not the distro or the install script

- **The distro is too old.** Ubuntu 24.04 ships rclone v1.60 (2022), old enough that pushes to R2 hit spurious
  `501 NotImplemented` on the first attempt (rclone retries and succeeds, so backups still land — but it is noise
  masking a real version lag).
- **`curl https://rclone.org/install.sh | sudo bash` is the wrong tool here.** It overwrites `/usr/bin/rclone` behind
  dpkg's back: dpkg keeps recording the distro version, and any later apt touch of the `rclone` package silently reverts
  the upgrade — the same two-package-managers-one-path landmine as `caddy upgrade`. It is also unpinned (fleet drift)
  and unverified.
- **A pinned, signed `.deb` through dpkg** fixes all of that: dpkg records the real version so apt never downgrades it,
  every host and every reprovision gets the same version, and the download is checksum-enforced against a signature we
  verified.

The pin lives in `roles/rclone/defaults/main.yml` — `rclone_version` and `rclone_deb_sha256`, bumped **together**.

## Bumping the version

Do this **on your laptop**, never on a host — the signature check is the whole point, and the host never gets a gpg key.
The signing key is Nick Craig-Wood's, fingerprint **`FBF737ECE9F8AB18604BD2AC93935E02FF3B54FA`** (see
[rclone release signing](https://rclone.org/release_signing/)).

```bash
ver=v1.74.4   # the version you are moving to

# 1. Import the signing key (once per laptop).
gpg --keyserver hkps://keyserver.ubuntu.com \
    --recv-keys FBF737ECE9F8AB18604BD2AC93935E02FF3B54FA
# Fallback if the keyserver is unreachable: curl -fsSL https://rclone.org/KEYS | gpg --import

# 2. Download the pinned .deb and the signed checksum list.
curl -fsSLO "https://downloads.rclone.org/$ver/rclone-$ver-linux-amd64.deb"
curl -fsSLO "https://downloads.rclone.org/$ver/SHA256SUMS"

# 3. Verify the signature — must say "Good signature from Nick Craig-Wood".
gpg --verify SHA256SUMS

# 4. Confirm the .deb matches the signed list, and print the hash to commit.
gpg --decrypt SHA256SUMS 2>/dev/null | grep "rclone-$ver-linux-amd64.deb"
sha256sum "rclone-$ver-linux-amd64.deb"
# The two hashes must be identical. That value is rclone_deb_sha256.
```

Then, in `roles/rclone/defaults/main.yml`, set `rclone_version` to `$ver` and `rclone_deb_sha256` to the verified hash,
and re-converge the baseline. The role's `get_url` re-checks the committed hash on every host, so a mismatched download
fails there rather than installing.

The role's `get_url` re-checks that committed hash on every host, so a tampered or truncated download fails the converge
loudly rather than installing.

## Verifying it landed

```bash
rclone version    # on the host — matches rclone_version
dpkg -s rclone | grep ^Version   # dpkg agrees, so apt will not downgrade it
```
