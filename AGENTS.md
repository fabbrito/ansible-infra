# Conventions

This is an Ansible **collection**. It ships the roles and playbooks that converge Ubuntu VPS hosts; it does not own an
inventory, a vault, or a host, and it never reaches one. Everything below follows from that: the artifacts are roles,
the gate is a static `make check`, and the thing that can go wrong is somebody else's host, on somebody else's converge.

The consuming repo — the controller — holds inventory, secrets, service roles, and the converge. Read `README.md` for
the seam between the two before changing anything that crosses it.

## Language

All developer-facing text is **English** — comments, commit messages, variable names, docs. Nothing here renders copy an
end user reads; if that ever changes, the copy follows the consumer's locale while the code around it stays English.

## Naming

- **Roles** are kebab-case, named for the thing they install (`caddy`, `fail2ban`). One role per installable concern.
- **Role variables are prefixed with their role** — `caddy_routes`, `os_swap_size`, `docker_cleanup_until`. Ansible's
  var namespace is flat and has no scoping; the prefix is what keeps two roles from colliding.
  - `ansible-lint` enforces `var-naming[no-role-prefix]` (production profile, no skip), so an unprefixed role var —
    including `register:`/`set_fact:` — fails the gate.
- **Vars that cross roles carry no prefix and are a CONTRACT, not a default.** A collection cannot ship `group_vars`, so
  `deploy_user` and `infra_install_dir` are set by the consumer and merely consumed here. Adding one is a breaking
  change to that contract: it goes in the README table and in `CHANGELOG.md`, in the same commit.
- **Files** follow Ansible's layout, which is load-bearing: `tasks/main.yml`, `defaults/main.yml`, `handlers/main.yml`,
  `templates/*.j2`. Ansible reads these paths; they are not free-form.
- Markdown stays kebab-case.

## Nothing in here names a consumer

This layer is shared across teams and across clients. A comment, a default, or a doc that names a client, a client's
vendor, a client's domain, or a downstream repo has leaked — it is wrong here even when it is accurate.

Keep the fact, drop the name: _"a payment provider's settlement callback"_ carries the same warning as the bank's name
and travels. The same goes for defaults: a role default that encodes one fleet's domain or mailbox is a bug, because the
next consumer inherits it silently. Default to empty and assert, or default to empty and degrade — and say which.

## Comments

A comment earns its place by carrying what the YAML can't, in as few words as it takes. Sequencing is most of this
repo's logic and almost none of it is visible in the tasks, so the facts below are worth writing down — tersely. A
paragraph is a fact plus padding; keep the fact.

- **Hidden contracts** — what a task assumes, what the next one needs. `ufw` opens ingress before it flips to
  deny-default; `os` swaps before the apt upgrade that would OOM without it. Reorder either and the host breaks.
- **Interface intent** — what a role or a var is _for_. `defaults/main.yml` is the role's public API, and here it is the
  API a team you will never talk to reads: what setting a var buys, not that it has a default.
- **Quirks** — the guard, the workaround, the landmine. `when: not ansible_check_mode`, `creates:`, swap gated on
  `/proc/swaps`, `caddy upgrade` clobbering the apt binary: each is a failure we hit. Name the failure, not the story.
- **Why, not how** — the alternative and why it lost: `deb822_repository` over `apt_repository`, `no_check_bucket` on
  the R2 remote, `sshd -G` over `sshd -t`.

Do not restate the module, label the obvious, or repeat the task's own `name:`. Do not narrate, argue with yourself, or
recount a comment's own history. A line or two; if it genuinely needs more, it is a `docs/` page or an ADR, and the
comment points at it.

## Docs

`docs/` holds **runbooks** — procedures a human follows, in order, to get a result. They are read by operators of fleets
we do not run, so they describe the role's mechanics and never a particular fleet's inventory.

- **Stay operational.** A runbook is steps and their rationale, not a transcription of what the roles do. The roles are
  the source of truth for mechanics.
- **Point, don't pin.** Reference roles and files as navigation pointers. Never cite line numbers, and never paste task
  YAML into a doc — it goes stale the moment the role changes.
- **Why over how.** Capture the reasoning that made an approach right, so a reader can tell when it stops being right.

Ask: will this still be true after a refactor that preserves behavior? If not, it belongs in a code comment next to the
thing, not in a doc.

## Commits

Commits follow `type(scope): subject`.

- **Scope is the role or layer** — `caddy`, `os`, `docker`, `ci`, `galaxy`. Reuse a scope the history already reaches
  for (`git log --format='%s'`) before coining one; omit it when the change is genuinely repo-wide.
- **Type** — `feat`, `fix`, `refactor`, `chore`, `style`, `docs`, `ci`, `build`, `perf`. Name what the commit did, not
  how big it was.
- **Subject** — concise, imperative, lowercase, no trailing period.
- **Bias hard to terse.** Subject-only by default; add a body only when one line can't carry it, and then write short
  bullet topics, not prose.
- **One commit per change.** Each fix or refactor is atomic and independently revertable.
- **Green between commits.** Every commit leaves `make check` passing — format, playbook syntax, `ansible-lint`,
  `shellcheck`, collection build. Never commit a red tree.
- If an AI co-authored, end with a `Co-Authored-By:` trailer naming the model, after a blank line. Never a session URL
  or any other link into a private session.

> [!IMPORTANT] **No internal codes.** Tracking ids coined while working — review-finding ids, plan-step ids, severity
> labels (`P0`), phase labels — never reach a commit message, a doc, a code comment, or an issue. A reader without your
> scratch notes cannot resolve them. Either **strip** the label (describe the actual thing) or **promote** it (define it
> as a real concept in `docs/`, after which it resolves). Real-world ids (CVE numbers, RFC numbers) are fine.

> [!IMPORTANT] **No secrets, no host data, no consumer data.** This repo has no vault and must never acquire one. A
> credential, a certificate, a private key, a hostname, or a public IP belonging to any fleet does not belong here — not
> in code, not in a commit message, not in a doc.

## Releases

The consumer pins a git tag, so **a change that is not released is a change nobody gets.**

- `galaxy.yml`'s `version:`, the `CHANGELOG.md` heading, and the git tag move together, in one commit plus one tag.
- A change to the contract in `README.md` — a new required var, a default that stopped being safe, a renamed role — is a
  **major** bump and says so in the changelog under "Changed".
- Never point a consumer at a branch. The pin is the whole safety mechanism.

## Secrets

This repo holds none, and that is structural: there is no `vault.yml`, no `.vault_pass`, and no inventory to attach them
to. What lives here is how roles _behave_ around a consumer's secrets.

- **Any task that renders a secret carries `no_log: true`.** Without it the value lands in the play output and in the
  consumer's CI logs.
- **A role whose secret is absent skips its work, it does not fail.** `rclone` installs the binary but renders no config
  without R2 creds; `docker` skips the registry login without a token. This is what lets a host join a fleet before its
  secrets exist. Preserve it in new roles.
- **Except where absence is itself unsafe.** An admin-less Beszel hub answers unauthenticated, so `monitoring` asserts
  instead of skipping. When you choose to assert rather than skip, say why in the comment — the default is to skip.
- A role documents its expected keys in its own `defaults/main.yml`, and the cross-cutting ones in the README table.
  Documenting a key is not the same as shipping it; never ship a value.

## Idempotence and safety

These are the invariants that make a converge re-runnable. They're the whole game, and here they are also a promise to a
team whose hosts we never see.

- **Every role is safe to re-run.** A second converge on an already-converged host changes nothing. A task that can't
  express this natively gets `creates:`, a `stat` guard, or an explicit `changed_when:` — never a blind `command:` that
  reports changed on every run.
- **A converge must not be able to lock the operator out.** Two live examples, and the pattern generalizes: open the
  firewall port before enabling deny-by-default; validate the sshd config before the handler reloads. When a task can
  sever Ansible's own connection, the guard comes first, in the same run.
- **`--check` must survive.** A task that cannot run in check mode (because a prior task's package isn't really
  installed) is gated `when: not ansible_check_mode`, so the consumer's dry-run reports cleanly instead of erroring.
  This repo cannot test that; a broken guard surfaces as a downstream failure, which is exactly why it is a rule.
- **Reboots are explicit and serial.** `update.yml` is `serial: 1`. A fleet never reboots at once.
- **Rendered files announce themselves.** Every template opens with `# Rendered by Ansible — do not edit on host`, plus
  its source path. Someone will find the file at 3am and needs to know editing it is pointless.
- **Service roles declare no meta dependencies.** Bootstrap and the baseline run first, by playbook order. Meta deps
  would re-walk `os` + `docker` on every service deploy.

## Verification

There is no unit-test suite, and inventing one would test Ansible, not us. The gate here is:

```bash
make check    # fmt-check + lint — what CI runs; must be green to commit
```

- **`make check` is static** — formatting, playbook syntax, `ansible-lint` (must stay clean at the **production**
  profile), `shellcheck`, and a collection build. It touches no host.
- **The gate that matters is downstream and you cannot run it.** A `--check --diff` dry-run against a real box, and a
  second converge reporting zero changed, both belong to the consuming repo. Behaviour changes therefore land as a
  release the consumer adopts deliberately — never as a quiet fix to a branch someone tracks.
- **FQCN resolution is part of the gate.** `playbooks/baseline.yml` names its roles `capybaralabs.infra.*`;
  `scripts/lint.sh` stages a symlink so a syntax-check resolves them against the working tree. A role renamed without
  updating the playbook fails there.

# Tooling

- **Make is the entrypoint**, and it is thin on purpose: it delegates to `scripts/` and `ansible-galaxy`. Real logic
  lives in roles and scripts, never in a recipe. There are no converge targets, because there is nothing to converge.
  - `make deps` — install the collections the roles depend on
  - `make fmt` / `make check` — autofix / verify
  - `make build` — build the collection tarball
- **Collection dependencies are pinned to majors in `galaxy.yml`**, which is what a consumer resolves, and mirrored in
  `requirements.yml` for local linting. **Change both or neither.** The `ansible-core` floor lives in
  `meta/runtime.yml`, enforced at install time and re-checked by `scripts/lint.sh`.
- **Bash follows the [YSAP style guide](https://style.ysap.sh)**, which is the source of truth for the mechanics — don't
  restate them here. `make fmt` applies this repo's flags (`shfmt -i 0 -ci`: tabs, indented `case` patterns, ≤ 80
  columns) and `make check` runs `shellcheck -x`. One point is worth pinning here, because it is the one that gets
  reverted:
  - **No `set -e`.** Errexit hides the failure that matters. Check explicitly instead: `cd "$dir" || exit 1`,
    `cmd || fail=$((fail + 1))`, and a hard guard before any step that is unsafe to reach after a partial failure.
  - `set -uo pipefail` stays: the guide only rejects errexit, and an unset variable or a swallowed pipe failure is
    exactly the silent bug we are trying to avoid.
- **Search with `rg`**, never `find` or `grep`.

## Agent skills

Configuration the engineering skills read. `docs/agents/` is the one part of `docs/` that is not a runbook.

### Issue tracker

GitHub issues on this repo's `origin`, driven by the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, unrenamed: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` at the root (not yet created), one `docs/adr/`. See `docs/agents/domain.md`.
