# Triage Labels

The five canonical triage roles, used **unrenamed** — each label string is its role name. That is the whole mapping;
this file exists so a skill has somewhere to look it up rather than assume it.

| Label             | Meaning                                  |
| ----------------- | ---------------------------------------- |
| `needs-triage`    | Maintainer needs to evaluate this issue  |
| `needs-info`      | Waiting on reporter for more information |
| `ready-for-agent` | Fully specified, ready for an AFK agent  |
| `ready-for-human` | Requires human implementation            |
| `wontfix`         | Will not be actioned                     |

When a skill names a role ("apply the AFK-ready triage label"), use the string from this table.

**These are not all present on the tracker.** Only `wontfix` exists there today, as a GitHub default. A skill that needs
one of the others creates it first (`gh label create <name> --force`) rather than failing on an unknown label — the same
applies to the `wayfinder:*` labels `issue-tracker.md` asks for.
