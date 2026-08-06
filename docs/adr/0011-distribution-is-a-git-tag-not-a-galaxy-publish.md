# 11. Distribution is a git tag, not a Galaxy publish

- **Status:** accepted
- **Date:** 2026-08-06

## Context

This is a collection, and the default assumption about a collection is that it ends up on Ansible Galaxy. The namespace
was renamed to match the owning GitHub account partly so that door stays open — Galaxy grants namespaces from that
identity, and a mismatch would have closed it permanently.

The door being open is not a reason to walk through it. The question is what publishing buys a consumer that a git tag
does not, and the answer turned out to be smaller than expected.

The structural argument for publishing was believed to be dependency resolution: that a collection's `galaxy.yml`
`dependencies:` can only name collections resolvable from a Galaxy server, so a git-sourced collection could never be a
dependency of another collection. **That is false, and it was tested rather than reasoned about.** A throwaway
collection declaring `git+https://github.com/…: v1.0.0` builds, installs, and resolves the git dependency transitively —
after which that collection's own Galaxy dependencies resolve normally on top. Git sourcing composes.

What remains is real but small: Galaxy offers version-range resolution, discoverability through search, and the short
`ansible-galaxy collection install <ns>.<name>` form.

## Decision

**The collection is distributed as a git tag. It is not published to Ansible Galaxy.**

Consumers declare it in their own `requirements.yml`:

```yaml
collections:
  - name: git+https://github.com/<owner>/<repo>.git
    type: git
    version: v1.0.0 # a tag, never a branch
```

The repository is public, so the fetch needs no credential and works from a CI runner with no deploy key.

## Consequences

- **No version ranges — and that is alignment, not a loss.** With a git source, `version:` is a ref: a tag, a branch, or
  a commit. `>=1.0.0,<2.0.0` is not available. But [ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md)
  already makes adopting a version a deliberate act gated on the consumer's dry-run and second converge, and the README
  already forbids pointing a consumer at a branch. A range would let a consumer drift onto a version nobody chose, which
  is the thing the pin exists to prevent.
- **We keep the ability to correct a tag, and give it up anyway.** A Galaxy version is immutable once published: a
  mistake ships forever, beside its fix. A git tag can be repointed. That freedom was used twice before this repo went
  public and is now spent — a published tag is frozen by policy rather than by the registry, and the next correction is
  a new version. The discipline is the same; only the enforcement differs.
- **Discoverability is not a goal.** This layer is handed to teams with a URL. Nobody needs to find it by searching, and
  the short install form is cosmetic.
- **Each install re-clones.** Git sourcing fetches from the forge where Galaxy would serve a cached artifact. Negligible
  at this size, and a consumer's `make deps` already pays the same cost for its other collections.
- **No release infrastructure.** No namespace claim to maintain, no API token in CI, no publish step per version, and no
  `galaxy-importer` acting as a validation gate whose rules the local gate does not model.

## What would change this

Any one of these makes the decision worth reopening. None hold today.

- **Third parties we do not talk to start consuming it.** A stranger handed a URL is fine; a stranger who has to
  _discover_ it is not.
- **Version ranges become wanted.** That reverses the exact-pin doctrine above, so it is a change to
  [ADR-0003](0003-the-gate-is-make-check-and-a-second-converge.md) first and a packaging change second — never the other
  way round.
- **A second collection of ours depends on this one and both should install by name.** Git works, as tested above, but
  mixed sourcing across a family of collections is harder to explain than it is worth.
