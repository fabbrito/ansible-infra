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
