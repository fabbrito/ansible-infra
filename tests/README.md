# tests/

Not shipped — `tests` is in `galaxy.yml`'s `build_ignore`, so none of this reaches a consumer's tree.

## `sanity/`

Ignore entries for `ansible-test sanity`, run by `make sanity`. The format is rigid: one `<path> <test-name>` per line,
**no comments and no blank lines** — the `ignores` test fails the run for either. Hence this file.

One entry, repeated per supported ansible-core version because the filename must match the running core:

```
roles/docker/templates/docker-cleanup.sh.j2 shebang
```

`roles/docker` renders that template to `/usr/local/sbin/docker-cleanup`, mode 0755, and the systemd unit beside it
`ExecStart`s the path directly — so the shebang is what makes the file run, not a stray line the test would be right to
flag. Renaming the template does not help: the test reads file _contents_, keying on `#!` at byte 0.

Adding a version file is how support for a newer core arrives. Without one, `sanity` fails on that core with the shebang
finding, which is the honest outcome — better than a wildcard that would also swallow a real one.

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

Two rules the layout does not enforce:

- **A fixture may only set vars the role's `defaults/main.yml` declares.** `render-one.yml` re-reads the defaults before
  each fixture, and that is what clears the previous one's values — a var the defaults do not declare survives into
  every fixture sorted after it.
- **`steps/` includes the role's own task file where a derivation is security-critical**, rather than restating it.
  `steps/caddy.yml` includes `roles/caddy/tasks/routes.yml` for exactly this reason: a restated copy of ADR-0008's route
  union would drift from the role silently, on the one derivation the ADR exists to protect.

**One fixture per decision, not per host.** Each names the branch it exists to pin, in a comment at the top. A fixture
that sets everything at once tests nothing in particular and its diff is unreadable.
