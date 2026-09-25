# Agent guidelines

Ansible collection: roles and playbooks that converge Ubuntu 24.04+ hosts. It owns no inventory, vault or host, and
never reaches one; the dry-run and second converge are the consumer's, so write for them. `README.md` is the consumer
contract, `CONTEXT.md` the vocabulary, `docs/adr/` what is settled.

**Be concise, in English.** Code, comments, docs, commits: the fewest words that carry the fact.

## Workflow

1. Once per clone: `make deps && make hooks`. `make help` lists the rest.
2. Before changing a role, read its `defaults/main.yml`, the comments on the tasks you touch, and the ADRs naming it.
3. Touched a template: fixture for the branch, `make golden-update`, read the diff (`tests/README.md`). A template
   change with no golden diff changed nothing, or has no fixture.
4. Done: `make check` green and committed — the hooks enforce it and grade the message. `make test` and `make sanity`
   are release legs; `make release` runs them.

## Commits

- `type(scope): subject`, scope reused from `git log`: the role or layer. One change per commit, green between commits.
- The hook grades the shape and the gate runs the lanes, both from a vendored engine reading `.githooks/hooks.conf`: a
  rule changes there, never in prose here.
- A file no lane in that config matches is never checked. A new kind of file means a new lane.
- AI co-authored: `Co-Authored-By:` naming the model. Never a session link.

> [!IMPORTANT] **No internal codes.** Plan-step, finding, severity (`P0`) or phase ids stay in scratch notes. Describe
> the thing, or define it in `docs/`. Real-world ids (CVE, RFC) are fine. `make check-codes` sweeps.

## Releases

- `make release VERSION=x.y.z` stamps `galaxy.yml`, gates on every leg and tags; `make publish` sends it up. Both take
  `DRY_RUN=1`. There is no CI (ADR-0013): a release is the only time the slow legs run.
- `galaxy.yml` `version:`, `CHANGELOG.md` heading and git tag move together — write the CHANGELOG section first, or
  `make release` refuses. Consumers pin tags, never branches: a change not released is a change nobody gets.
- Contract change (new required var, unsafe default, renamed role): major, under "Changed".
- New authoring doc or repo-local tool path: add to `build_ignore` in the same commit. The build ignores `.gitignore`,
  and anything unnamed ships into a consumer's tree, where their agents read it.
- Collection deps: `galaxy.yml` and `requirements.yml` together. Core floor: `meta/runtime.yml` and `scripts/lint.sh`
  together.

## Secrets

> [!IMPORTANT] **No secrets, host data or consumer data** — credentials, certificates, keys, hostnames, public IPs — in
> code, docs or commits. This repo has no vault and never acquires one.

- Task rendering a secret: `no_log: true`.
- Absent secret: skip (ADR-0001). Assert only where absence is unsafe, and comment why.
- Keys documented in the role's `defaults/main.yml`, cross-cutting ones in the README table. Values never shipped.

## Nothing names a consumer

Shared across teams and clients: a client, its vendor, its domain or a consuming repo named in a comment, default or doc
has leaked, even when accurate. Keep the fact, drop the name: _"a payment provider's settlement callback"_. A default
encoding a fleet's domain or mailbox is a bug the next consumer inherits: default empty, then assert or skip, and say
which.

## Roles

- One role per installable concern, kebab-case, named for what it installs.
- Role vars carry the role prefix (`register:` and `set_fact:` too); `ansible-lint` enforces it.
- Unprefixed vars are the consumer contract (`deploy_user`, `infra_install_dir`): the consumer sets them. Adding one:
  README table and `CHANGELOG.md`, same commit.
- `defaults/main.yml` is the public API, read by teams you will never talk to: say what setting a var buys.
- Asserts check consumer input; goldens check our output. Neither replaces the other.
- Second converge reports zero changed: `creates:`, a `stat` guard, or `changed_when:` on every `command:`.
- `--check` survives: `when: not ansible_check_mode` where a prior install is fake; `check_mode: false` on read-only
  probes.
- No lock-out: open the firewall port before deny-default; validate sshd before the reload.
- Reboots are explicit and serial: `update.yml` is `serial: 1`.
- Rendered files open with `# Rendered by Ansible — do not edit on host` and the source path.
- Playbook order sequences roles; no meta dependencies.

## Shell

- [YSAP style](https://style.ysap.sh), 80 columns.
- `set -uo pipefail` with explicit checks (`cd "$dir" || exit 1`); errexit never.
- `scripts/` and `.githooks/` need bash 4.4+, the hook engine's own floor; host-side shell may assume GNU userland.
- Make recipes delegate — to `scripts/`, or to the vendored engine. Logic never accumulates in Make syntax.
- Search with `rg` and `fd`, never `grep` or `find`.

## Altitude

`code > comments > docs`. Altitude rises to the right; write at the lowest rung that holds the knowledge.

- **Code:** names, defaults, asserts, guards.
- **Comments:** focused on the line beside them; only what the code can't say — a hidden contract, a var's intent, a
  quirk's failure, the alternative that lost. A line or two; never restate the module or the task's `name:`.
- **Docs:** knowledge spanning several sources in the repo. `docs/<topic>/` runbooks for operators of fleets we do not
  run, `docs/adr/` decisions; kebab-case. Point at roles and files, never paste them or cite line numbers.

A comment reaching past its file belongs a rung up. A doc tied to one file belongs a rung down.

## Agent shell gotchas

- `ansible*` refuses non-blocking stdio and has no opt-out: the check runs at import, before any flag is read. This
  shell hands it a non-blocking stderr, so pipe the command through `cat` — `make check 2>&1 | cat`. Lanes cannot
  redirect, which is why the ansible legs sit in `scripts/lint.sh`.
- `cd` is wrapped by zoxide: use `builtin cd` or absolute paths.

## Agent skills

Configuration the engineering skills read. It configures authoring _this_ repo, so it is excluded from the build.

- **Issue tracker:** GitHub issues on `origin`, via `gh`. See `docs/agents/issue-tracker.md`.
- **Triage labels:** the five canonical roles, unrenamed. See `docs/agents/triage-labels.md`.
- **Domain docs:** single-context — one `CONTEXT.md`, one `docs/adr/`. See `docs/agents/domain.md`.
