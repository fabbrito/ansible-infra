# Domain Docs

How the skills consume this repo's domain docs. Single-context: one root `CONTEXT.md`, decisions in `docs/adr/`.

## Before exploring, read these

- **`CONTEXT.md`** — vocabulary.
- **`docs/adr/`** — ADRs touching the area you're about to work in; `docs/adr/README.md` indexes them.

Missing is fine: proceed silently, don't flag it; they get created lazily once terms or decisions actually resolve.

## Use the glossary's vocabulary

Name concepts (issue titles, proposals, role and var names) as `CONTEXT.md` defines them; don't drift to synonyms it
avoids. A missing concept is a signal — either you're inventing language, or it's a real gap worth recording.

## Flag ADR conflicts

Surface a contradiction rather than silently overriding:

> _Contradicts ADR-0002 (a converge can never lock us out), but worth reopening because…_

## What an ADR here may decide

Why a role has its shape. How a fleet is run — where a secret sits in a vault, which repo owns a host — is the
consumer's call, recorded in its own repo. A fully superseded ADR is deleted and its number consumed, never reused.
