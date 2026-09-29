# 21. Tailscale comes from its own apt repo, joined by an optional key

- Status: accepted

## Chosen

The tailscale role installs from Tailscale's apt repo, the Ubuntu or Debian flavour by distribution, and unattended-
upgrades keeps it patched. Its signing key is pinned by hash for the first download only; after that the keyring package
owns and rotates it. The join is an optional feature keyed on the auth key: set, a host off the tailnet joins with the
host's own DNS kept; unset, the role installs and the operator joins by hand. A joined host, or one an operator took
down, is left as it is.

## Why

Tailscale faces the network, so a pinned package goes stale in exactly the place it should not. The repo plus
unattended-upgrades keeps it current with no release of ours. Pinning the key's hash guards the first fetch; pinning it
forever would break the day Tailscale rotates it.

A key is read only by a join, so requiring it made every converge of a joined host carry a secret it never used, and a
spent single-use key failed hosts that needed nothing. Ansible serves fleets: a set key is a reusable one, and a small
box can be joined by hand.

The tailnet is additive: the host's own SSH path stays, and its resolver stays the LAN's or the provider's, so the
tailnet is never the only door.

## Cost

Tailscale's release cadence reaches every host unreviewed. A forgotten key no longer fails the converge: the host
installs, stays off the tailnet, and says so. A single-use key joins once, and a later rejoin fails loudly.

## Reverses

Pin a package version and bump it in releases, trading freshness for review; or accept the tailnet's DNS and make it a
dependency.
