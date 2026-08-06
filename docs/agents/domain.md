# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

This repo is **single-context**: one `CONTEXT.md` at the root, one `docs/adr/` tree.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the glossary.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. They are numbered and titled by their claim
  (`0002-a-converge-can-never-lock-us-out.md`), so the filename alone usually tells you whether it's relevant.
  `docs/adr/README.md` indexes them in one line each.
- **`AGENTS.md`** (`CLAUDE.md` symlinks to it) — the conventions the ADRs are enforced through.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront.
The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily
when terms or decisions actually get resolved.

Where a glossary entry and an ADR disagree, **the ADR wins** — an ADR that coins a term is the source, and the entry is
the summary that points back at it.

## File structure

```
/
├── AGENTS.md          ← conventions; CLAUDE.md is a symlink to it
├── CONTEXT.md         ← glossary (maintained lazily by /domain-modeling)
├── docs/
│   ├── adr/           ← decisions
│   ├── agents/        ← this directory: skill configuration
│   └── <topic>/       ← operator runbooks
├── playbooks/
└── roles/
```

`docs/` otherwise holds **runbooks** — procedures an operator follows in order. `docs/agents/` is the documented
exception: it is skill configuration, at the path the skills read.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a role or var name), use
the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project
doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

Two of this repo's naming rules bind harder than glossary preference, because the gate enforces them: role vars carry
their role prefix, and vars that cross roles are a contract in `README.md`. See `AGENTS.md`.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0002 (a converge can never lock us out) — but worth reopening because…_

## Writing a new ADR

**Does the decision explain why a role is shaped the way it is, or does it govern how a fleet is run?** Only the first
kind belongs here. Where a secret sits in a vault, how inventory expresses composition, which repo owns a host — those
are the consuming repo's calls, and an ADR here would hand its operators somebody else's policy.

## Never name a consumer

Everything the skills write — issues, ADRs, glossary entries, plans — is bound by the repo's rule that nothing here
names a client, a client's vendor, a domain, a host, or a consuming repo. Keep the fact, drop the name.
