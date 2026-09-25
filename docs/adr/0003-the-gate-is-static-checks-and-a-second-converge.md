# 3. The gate is static checks and a second converge

- Status: accepted

## Chosen

Five gates, in increasing order of truthfulness, and no unit suite.

- **The commit gate** — static, touches no host: formatting of the docs, shell and Ansible trees, shellcheck, the
  ansible-core floor, playbook syntax, and lint at the production profile. Every commit leaves it green.
- **Sanity, the goldens and the collection build** — static, and the first two read the rendered bytes. Sanity runs the
  checks core ships; goldens push fixtures through the real templates and diff the result against checked-in
  expectations, one fixture per decision. All are release legs, out of the commit hook on cost: a cold sanity run builds
  a virtualenv per supported Python.
- **A dry-run** against a real host, with the diff read.
- **A second converge** reporting zero changed. A sweep for plan labels is a manual target beside the gate, not a lane.

## Why

A test asserting a module installed a package tests Ansible, not this collection. What goes wrong here is a host, and a
host is not something a suite holds. What is left is hand-written idempotence, whose quiet failure is a task that
reports changed on every run: the host ends correct, so nothing looks broken, and real drift hides in the noise. The
second converge is the only gate that catches it.

The commit gate reads tasks, never the bytes they produce. Lint passes a template that renders a proxy trusting the
whole internet, and the renderer finds it valid configuration. Sanity and the goldens exist for that blind spot.

## Cost

A dry-run is not proof: a task whose prerequisite was never really installed cannot run under check, so it is skipped to
keep the output clean. An unexpected diff is still real, and worth the run.

The commit gate syntax-checks every play and dry-runs none. There is no host here, so the dry-run leg and any exclusion
a destructive play needs belong to the consuming repo's gate.

A template change with no golden diff means either nothing changed or no fixture covers the branch you touched. Adding a
branch means adding a fixture in the same commit.

## Reverses

A unit suite able to hold a host; or a golden per template branch, which would leave the dry-run less to prove.
