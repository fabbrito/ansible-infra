# Monitoring: access and first-time pairing

The `monitoring` role stands up an observability stack on any host the consumer assigns it to:

- **Beszel** — host + per-container metrics, history, and threshold alerts (hub + agent, talking over a shared unix
  socket on the same box).
- **Dozzle** — a real-time container log viewer, the fast path to _which_ worker loop is firing when one pegs a core.

Neither is exposed publicly. Both bind to loopback and are reached over an SSH tunnel: anything put in front of them has
to supply the authentication they do not have. Everything below is _why_ and _in what order_; the role is the source of
truth for mechanics.

## Reach the dashboards

The hub and Dozzle listen on the box's loopback only. Forward the ports over SSH:

```bash
ssh -L 9090:127.0.0.1:9090 -L 9080:127.0.0.1:9080 <deploy_user>@<host>
```

Then, in a browser on your machine:

- Beszel hub → <http://localhost:9090>
- Dozzle → <http://localhost:9080>

(Ports are role defaults — `monitoring_hub_port` / `monitoring_dozzle_port`.)

## First converge — what comes up

The hub and Dozzle need no secret, so they start on the first converge. The agent does **not**: it needs a key and token
that only the running hub can mint, so it stays down until you pair it. This is the
[ADR-0015](../adr/0015-a-declared-role-asserts-its-secrets.md) pattern — a box joins the group and monitors nothing
until its secrets exist, rather than failing the play.

`monitoring_admin_email` and `monitoring_admin_password` are the exception: both are **asserted**, so the role refuses
to converge without them. An admin-less hub starts, serves, and never creates a first user, which is not a converged end
state. Set them and the hub creates the admin on first boot (`USER_EMAIL` / `USER_PASSWORD`).

## Pair the agent (one time)

1. Converge the box, then open the hub over the tunnel and sign in.
2. **Add System.** For a same-box agent, set the host to the shared socket path:

   ```
   /beszel_socket/beszel.sock
   ```

   The dialog shows a **public key** and a **token**.

3. Put them where the role reads them, scoped to the group that shares the hub:
   - the public key → `monitoring_agent_key`, as plain group vars (it authenticates nothing, so it is config);
   - the token → `monitoring_agent_token`, in that group's **vault** (`ansible-vault edit`, or `create` if it does not
     exist yet).
4. Re-converge. The role now renders the agent into the compose and starts it; within a cycle the system reports live in
   the hub. Re-runs are idempotent.

## Rotating or revoking

- **Token** — delete the system in the hub UI and re-add it, then update the vault and the `monitoring_agent_key` and
  re-converge.
- **Pulling the token** from the vault removes the agent on the next converge (the compose no longer renders it;
  `remove_orphans` tears it down). The hub and Dozzle stay up.
