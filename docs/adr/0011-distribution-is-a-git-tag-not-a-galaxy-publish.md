# 11. Distribution is a git tag, not a Galaxy publish

- Status: accepted

## Chosen

The collection is distributed as a **git tag**. It is not published to a Galaxy server.

A consumer names the repository as a git source in its own requirements, pinned to a tag and never a branch. The
repository is public, so the fetch needs no credential and works from a runner holding no deploy key.

## Why

Publishing was believed necessary for **dependency resolution**: that a collection's declared dependencies could only
name collections a Galaxy server resolves, so a git-sourced collection could never be another collection's dependency.
That is false, and it was tested rather than reasoned about. A throwaway collection declaring a git dependency builds,
installs, and resolves it transitively, with that collection's own Galaxy dependencies resolving normally on top. Git
sourcing composes.

What publishing would add is version ranges, discoverability by search, and a shorter install form. None is wanted. This
layer is handed over with a URL, and a range would let a consumer drift onto a version nobody chose — the exact thing
the pin exists to prevent.

## Cost

**No version ranges.** With a git source a version is a ref, not a range. That is alignment rather than loss: the gate
already makes adopting a version a deliberate act.

**A tag can be repointed; a published version cannot.** That freedom was used twice before this repository went public
and is now spent. A published tag is frozen by policy rather than by a registry, and the next correction is a new
version — the same discipline, enforced by us instead of by the registry.

**Each install re-clones** from the forge where a registry would serve a cached artifact. Negligible at this size, and a
consumer's dependency step already pays the same cost for its other collections.

There is no release infrastructure to maintain: no namespace, no API token, no publish step per version, and no importer
acting as a validation gate whose rules the local gate does not model.

## Reverses

Third parties we do not talk to starting to consume it — a stranger handed a URL is fine, a stranger who must discover
it is not. Or version ranges becoming wanted, which reverses the exact-pin doctrine first and is a packaging change
second, never the other way round. Or a second collection of ours depending on this one, with both wanted by name.
