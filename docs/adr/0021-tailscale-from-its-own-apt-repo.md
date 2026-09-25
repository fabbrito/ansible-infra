# 21. Tailscale comes from its own apt repo, joined by a required key

- Status: accepted

## Chosen

The tailscale role installs from Tailscale's apt repo, the Ubuntu or Debian flavour by distribution, and unattended-
upgrades keeps it patched. Its signing key is pinned by hash for the first download only; after that the keyring package
owns and rotates it. The auth key is required. A host off the tailnet joins with the host's own DNS kept; a host an
operator took down stays down.

## Why

Tailscale faces the network, so a pinned package goes stale in exactly the place it should not. The repo plus
unattended-upgrades keeps it current with no release of ours. Pinning the key's hash guards the first fetch; pinning it
forever would break the day Tailscale rotates it.

The tailnet is additive: the host's own SSH path stays, and its resolver stays the LAN's or the provider's, so the
tailnet is never the only door.

## Cost

Tailscale's release cadence reaches every host unreviewed. The auth key stays vaulted even for joined hosts, and a spent
one fails the converge of a host not yet joined.

## Reverses

Pin a package version and bump it in releases, trading freshness for review; or accept the tailnet's DNS and make it a
dependency.
