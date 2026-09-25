# 13. There is no CI; the maintainer runs the gate before merge

- Status: accepted

## Chosen

No workflow runs on a push or a pull request.

- **Per commit:** the pre-commit hook runs the gate's lanes, and a second hook grades the commit message.
- **Per pull request:** the maintainer checks out the branch and runs the gate before merging. A contributor's green run
  is a claim, not proof.
- **Per tag:** the release command runs every leg the commit hook skips — goldens, sanity, what the tarball ships — and
  checks the tag against the built manifest. A release cannot be cut red.

## Why

CI ran the same static checks a laptop runs, and every one of them touches no host. So it proved nothing the hooks and
the release command could not, and it brought its own attack surface: one record existed only to guard it.

What a consumer gets is the tag. A green run on an untagged commit is evidence nobody installs.

## Cost

A pull request shows no status check, so merging without running the gate is possible and no tool here can stop it.

Hooks are opt-in per clone. A commit made without them is caught at the next gate run — before merge, or before release
— whichever comes first.

The repository settings a workflow would need still exist and now guard nothing. They are harmless, and the right
starting point if one comes back.

## Reverses

Enough outside contributors that running the gate by hand per pull request stops scaling. A workflow then comes back,
and the fork-boundary reasoning comes back with it from the top. Or anything that must run on infrastructure we do not
hold — a converge against a disposable machine — which is the first real reason for a runner.
