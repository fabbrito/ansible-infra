# Issue tracker: GitHub

Issues and specs live as GitHub issues, via the `gh` CLI. An issue is public history: no secrets, host data or consumer
names, as in git.

- **Create**: `gh issue create --title "..." --body "..."` (heredoc for multi-line).
- **Read**: `gh issue view <n> --comments`.
- **List**: `gh issue list --state open --json number,title,body,labels` plus `--label`/`--state` filters.
- **Comment**: `gh issue comment <n> --body "..."`.
- **Label**: `gh issue edit <n> --add-label "..."` / `--remove-label "..."`.
- **Close**: `gh issue close <n> --comment "..."`.

Repo inferred from `git remote -v`; `gh` does this inside a clone.

**PRs as a request surface: no.** _(Flip to `yes` if external PRs count as feature requests; the triage flow reads this
flag. Then use the `gh pr` equivalents.)_

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Claiming a ticket

An agent that takes on a ticket assigns itself before any other write: `gh issue edit <n> --add-assignee @me`. An
assigned ticket is claimed; don't start work on one without taking it first.

## Relationships

An issue can have sub-issues, and can be blocked by other issues. Both are native on GitHub:

- **Sub-issue**: `gh api` on the parent's sub-issues endpoint. Without it, a task list in the parent and `Part of #<n>`
  atop the child.
- **Blocked by**: `gh api --method POST repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by -F issue_id=<id>`, where
  `<id>` is the blocker's database id (`gh api repos/<owner>/<repo>/issues/<blocker> --jq .id`), not its number. Without
  it, a `Blocked by: #<n>` line atop the body.

An issue is ready when every blocker is closed and nobody is assigned.
