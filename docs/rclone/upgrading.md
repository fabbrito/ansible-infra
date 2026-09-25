# Upgrading rclone

`roles/rclone` installs a fixed upstream `.deb` per architecture. Changing `rclone_version` and its hashes is the only
way rclone changes version on a host.

## Why a fixed version

- Ubuntu 24.04, Debian and Raspberry Pi OS ship rclone 1.60 (2022), old enough to hit spurious `501 NotImplemented` on
  R2.
- rclone's `install.sh` overwrites `/usr/bin/rclone` behind dpkg, unpinned and unverified; any apt touch of `rclone`
  reverts it.
- A `.deb` through dpkg records the real version, and the committed sha256 is checked on every converge, so the host
  needs no gpg key.

## Bump

On the controller, never on a host. rclone's release signing key fingerprint is
`FBF737ECE9F8AB18604BD2AC93935E02FF3B54FA` ([release signing](https://rclone.org/release_signing/)).

```bash
ver=v1.75.1
export GNUPGHOME=$(mktemp -d)
curl -fsSL https://rclone.org/KEYS | gpg --import
gpg --fingerprint FBF737ECE9F8AB18604BD2AC93935E02FF3B54FA

curl -fsSLO "https://downloads.rclone.org/$ver/SHA256SUMS"
gpg --verify SHA256SUMS   # "Good signature from Nick Craig-Wood"
gpg --decrypt SHA256SUMS 2>/dev/null | grep -E "linux-(amd64|arm-v7|arm64)\.deb"
```

In `roles/rclone/defaults/main.yml`, set `rclone_version` and each `rclone_debs` hash from that verified list, in one
commit. `arm-v7` is `armhf`; nothing here installs the ARMv6 `linux-arm` asset.

## Check on a host

```bash
rclone version
dpkg -s rclone | grep ^Version
```
