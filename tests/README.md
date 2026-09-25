# tests/

Not shipped — `tests` is in `galaxy.yml`'s `build_ignore`, so none of this reaches a consumer's tree.

## `golden/`

Render tests: `make test` renders every fixture through the real templates and diffs the bytes against `expected/`.
`make golden-update` accepts the current render — a separate target on purpose, because accepting an expectation should
be a deliberate act with a diff to read afterwards.

**What this is for.** `ansible-lint` checks the tasks and `caddy validate` checks the syntax; neither can see a config
that is valid and says the wrong thing. Three live examples, all of which `caddy validate` passes:

- a `servers` trust block on a host nothing fronts — anyone pointing a zone at the host's IP becomes a trusted peer
- a matcher-less default `request_body`, which composes with the per-path caps and clamps every one of them
- a redaction filter on one logger and not the other, so the credential reaches the journal while the access log looks
  clean

Asserts validate the consumer's _input_. Goldens validate our _output_. The rclone bug that started this had a correct
assert that passed.

**Layout.**

```
golden/
  render.yml            # the play: find fixtures, loop, render. One run, not one per fixture
  render-one.yml        # per fixture: load defaults, load fixture, render
  steps/<role>.yml      # what to render for that role, and any pre-render derivation
  fixtures/<role>/<case>.yml
  expected/<role>/<case>/<file>
```

**Adding a case** is one fixture file plus `make golden-update`. Adding a _role_ is a `fixtures/<role>/` directory and a
`steps/<role>.yml`; nothing else changes.

Three rules the layout does not enforce:

- **Fixtures do not isolate themselves.** `render-one.yml` re-reads the role's `defaults/main.yml` before each fixture,
  and that re-read is the only thing clearing the previous fixture's values. A var the defaults do **not** declare — a
  contract var like `infra_install_dir`, or anything vaulted in the consuming repo — survives into every fixture sorted
  after it. So every fixture that cares about such a var sets it explicitly, including to empty:
  `monitoring/unpaired.yml` sets `monitoring_agent_token: ""` for exactly this reason, and without it that case would
  quietly become a second copy of `paired`.
- **`steps/` includes the role's own task file where a derivation is security-critical**, rather than restating it.
  `steps/caddy.yml` includes `roles/caddy/tasks/routes.yml` and `steps/monitoring.yml` includes
  `roles/monitoring/tasks/pairing.yml`. Both are one `set_fact` that would be trivial to copy, and both are the exact
  derivation an ADR exists to protect — a copy drifts from the role silently.
- **Every value in a fixture is fake, and looks it.** The roles read real secrets from a consumer's vault; this repo has
  none and must never acquire one. Where a template renders a secret, the fixture supplies something no one could
  mistake for live (`golden-fixture-not-a-token`) and the expectation is named so no scanner reads it as a leak —
  `steps/monitoring.yml` writes `env`, not `.env`. The destination filename belongs to the task, not the template, so
  nothing is lost by choosing a different one here.

**One fixture per decision, not per host.** Each names the branch it exists to pin, in a comment at the top. A fixture
that sets everything at once tests nothing in particular and its diff is unreadable.
