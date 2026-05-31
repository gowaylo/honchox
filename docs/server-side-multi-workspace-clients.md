# Server-side multi-workspace clients

Use one Honcho workspace per tenant when your application runs agents for multiple customers.

Your server keeps the admin API key. For each request, job, or agent run, build a Honchox client with the tenant's workspace ID. The client is immutable and stateless, so creating one per tenant context is safe and cheap.

```elixir
admin_api_key = System.fetch_env!("HONCHO_API_KEY")

tenant_a =
  Honchox.new(
    api_key: admin_api_key,
    workspace_id: "tenant_a"
  )

tenant_b =
  Honchox.new(
    api_key: admin_api_key,
    workspace_id: "tenant_b"
  )
```

Each client uses the same admin key, but resource operations are scoped by the client's `workspace_id`.

```elixir
{:ok, agent_a} = Honchox.peer(tenant_a, "support-agent")
{:ok, user_a} = Honchox.peer(tenant_a, "end-user")
{:ok, session_a} = Honchox.session(tenant_a, "conversation-main")

:ok = Honchox.Session.add_peers(session_a, [agent_a, user_a])

{:ok, _messages} =
  Honchox.Session.add_messages(session_a, [
    Honchox.Peer.message(user_a, "Hello from tenant A"),
    Honchox.Peer.message(agent_a, "Acknowledged for tenant A")
  ])
```

For another tenant, use a different `workspace_id`:

```elixir
{:ok, agent_b} = Honchox.peer(tenant_b, "support-agent")
{:ok, user_b} = Honchox.peer(tenant_b, "end-user")
{:ok, session_b} = Honchox.session(tenant_b, "conversation-main")

:ok = Honchox.Session.add_peers(session_b, [agent_b, user_b])

{:ok, _messages} =
  Honchox.Session.add_messages(session_b, [
    Honchox.Peer.message(user_b, "Hello from tenant B"),
    Honchox.Peer.message(agent_b, "Acknowledged for tenant B")
  ])
```

Listing resources stays within the workspace configured on the client:

```elixir
{:ok, tenant_a_peers} = Honchox.peers(tenant_a)
{:ok, tenant_a_sessions} = Honchox.sessions(tenant_a)
{:ok, tenant_a_messages} = Honchox.Session.messages(session_a)
```

## When to use scoped keys

If all agents run on your own server, you usually do not need to create scoped keys for every agent. Keep the admin key server-side and choose the correct `workspace_id` for each tenant operation.

Use `Honchox.Keys` when you need to delegate limited access to another process or boundary that should not receive the admin key, such as a frontend, third-party integration, or isolated worker.

```elixir
{:ok, scoped_client} =
  Honchox.Keys.create_client(tenant_a,
    workspace_id: "tenant_a",
    expires_in: {1, :hour}
  )
```

## Live smoke test

The repository includes a live smoke script for this scenario:

```sh
set -a
source .env
set +a
unset HONCHO_URL
mix run scripts/live_multi_tenant_test.exs
```

The script creates two workspaces, registers tenant-specific peers and sessions, adds messages, and lists each workspace's resources to verify the client behavior.
