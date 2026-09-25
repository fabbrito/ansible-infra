# fabbrito.infra

Ansible collection: composable roles for long-lived Debian-family hosts, cloud VMs and boards. What a consumer sets and
gets is `README.md`; vocabulary is `CONTEXT.md`; settled decisions are `docs/adr/`. The collection owns no inventory,
vault or host.

**Write terse.** Sacrifice grammar for concision — prose, comments, commits, this file.

## Defer

Defer building until a consumer needs it; revise decisions as issues surface.

Exempt from deferral — decide before the code lands. The test is reversibility cost, not importance:

- the contract — unprefixed vars, role names, defaults a consumer relies on
- anything a converge leaves on a host that a later release must read or remove
- the path between Ansible and SSH — firewall and sshd order

## Hosts are the consumer's to run

This repo reaches no host. The dry-run and the second converge run in the consumer's repo, on the tag it adopts; write
for them. Agents write roles and hand over the command; `make check`, `make test` and anything offline stay agent work.

## Guardrails

- No secrets, host data or consumer data in git: credentials, keys, certificates, hostnames, IPs, the name of a client,
  its vendor or a consuming repo. Keep the fact, drop the name. Issues count as git.
- A task rendering a secret: `no_log: true`.
- A default encoding one fleet's domain or mailbox is a bug the next consumer inherits: default empty, then assert.
- No internal codes (plan steps, finding ids, `P0`) in commits, docs or comments. `make check-codes` sweeps.
- The repository is public; a disclosure is what no later commit undoes.

## The commit gate

Once per clone: `make deps && make hooks`. `.githooks/githooks` is a vendored engine: all policy in
`.githooks/hooks.conf`. Bump it by copying a newer tag over it; `commit-msg` and `pre-commit` are shims and are never
edited.

The gate is lanes matching paths by glob. A file no lane matches is never checked, so a new kind of file means a lane. A
missing tool fails: a skipped lane is not a green commit. Beyond `ansible-core`: `ansible-lint`, `shellcheck`, `shfmt`,
`npx`. The goldens and `ansible-test sanity` are not lanes — too slow to sit between you and a commit; they are
`make test` and `make sanity`, and `make release` runs both. There is no CI.

## Roles

- One role per installable concern, named for what it installs. The consumer's plays order roles; no meta dependencies.
- Role vars carry the role prefix, `register:` and `set_fact:` too. Unprefixed vars are the contract: README table and
  `CHANGELOG.md` in the same commit; read with `| default(...)` so an unset one reaches the assert.
- `defaults/main.yml` is the public API: say what setting a var buys.
- Assert preconditions and cheap postconditions from host state, never from a "role ran" marker. A role's own secret is
  a precondition; an optional feature is keyed on its secret, said beside the key.
- Second converge reports zero changed. `--check` survives: `check_mode: false` on read-only probes, skip what a fake
  install breaks.
- No lock-out: every rule before deny-default, sshd validated before its reload.
- A rendered file opens with `# Rendered by Ansible — do not edit on host` and its source path.

## Comments earn their keep

A comment carries knowledge from outside the code it sits on: why this choice, what breaks otherwise, the gotcha the
module hides. Narration of the task below it goes stale and dies. One line where one line does.

## Promote what spans

Where knowledge lives, in order: `code > comments > docs > README`. Moving right raises altitude; write at the lowest
level that holds the knowledge.

| Where           | Holds                                                                          |
| --------------- | ------------------------------------------------------------------------------ |
| `README.md`     | the consumer contract — roles, vars, platforms, how to compose                 |
| `AGENTS.md`     | how to work here — the process an agent follows, never facts about the roles   |
| `CONTEXT.md`    | domain vocabulary                                                              |
| `docs/<topic>/` | runbooks for operators of fleets we do not run                                 |
| `docs/agents/`  | how the engineering skills read this repo — issue tracker, labels, domain docs |

A settled decision the collection still lives under a year from now goes to `docs/adr/` — `## Chosen`, `## Why`,
`## Cost`, `## Reverses`, no paths or symbols.

Contradicting a row is allowed. Doing it quietly is not — name the line, and say which of the two you would change.

**AGENTS.md is not a knowledge base.** The test: a rule that survives the roles being rewritten is process, and stays. A
rule that stops being true when a role changes was a comment all along.

Name things in `CONTEXT.md`'s vocabulary. A concept the glossary has no term for is a signal, not a gap to fill in
passing.

## The hidden contract

`.tmp/` holds plan-internal material — plans, handoffs, session scratch — and may go stale. `docs/`, the README and
commits never mention it.

The build ships everything `galaxy.yml`'s `build_ignore` does not name, into a consumer's tree, where their agents read
it. A new authoring doc or tool path joins `build_ignore` in the same commit.

## Tests bite

| Where          | Mechanism                                                                  |
| -------------- | -------------------------------------------------------------------------- |
| Consumer input | **assert** before the role changes anything — fail loud, name the var      |
| Host state     | **assert** a postcondition read back from the host                         |
| Our output     | golden: a fixture per template branch, `make golden-update`, read the diff |
| The specific   | a fixture for the exact bug, once found                                    |

A template change with no golden diff changed nothing, or has no fixture.

## Releases

- `make release VERSION=x.y.z` stamps `galaxy.yml`, gates on every leg and tags; `make publish` pushes and cuts the
  release. `DRY_RUN=1` on both.
- `galaxy.yml` version, `CHANGELOG.md` heading and the tag move together: write the CHANGELOG first.
- Contract change — new required var, unsafe default, renamed role: major, under "Changed". A var only a new opt-in role
  reads: minor, under "Added".
- Collection deps: `galaxy.yml` and `requirements.yml` together. Core floor: `meta/runtime.yml` and `scripts/lint.sh`.

## Shell

- [YSAP style](https://style.ysap.sh), 80 columns. `set -uo pipefail` with explicit checks; errexit never. `scripts/`
  and `.githooks/` need bash 4.4+.
- Make recipes delegate — to `scripts/` or the engine.
- A script that runs `ansible*`, run by an agent, guards its stdio: `ansible*` refuses non-blocking stdout or stderr,
  which agent shells hand it. Redirect through `cat`.
- Errexit's one exception: a script rendered onto a host as a systemd oneshot, which should fail its unit.

## Commits

- Never a red tree: every commit passes `make check`.
- `type(scope): subject`, scope a role or a cross-cutting name from `git log`. Subject-only by default; cut every word
  the diff already says.
- AI co-authored: `Co-Authored-By:` naming the model. Never a session link — history is permanent.

## Agent skills

- **Issue tracker:** GitHub issues, via `gh`. `docs/agents/issue-tracker.md`.
- **Domain docs:** single-context — one `CONTEXT.md`, one `docs/adr/`. `docs/agents/domain.md`.
