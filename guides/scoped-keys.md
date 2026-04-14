# Scoped Keys

Honcho uses JWT-based API keys with a hierarchical permission model. An admin
client can mint **scoped keys** that restrict access to a specific workspace,
peer, or session. This is useful for delegating limited access to frontends,
third-party integrations, or background workers without exposing the admin key.

## How it works

The admin key (`api_key`) has full access to all resources. When you create a
scoped key, Honcho signs a new JWT with claims that limit which resources the
bearer can reach. The key is **stateless** — it is not stored on the server,
and cannot be revoked individually. Use expiration to control its lifetime.

### Permission hierarchy

| Scope | Access |
|-------|--------|
| **Workspace** (`workspace_id`) | All peers, sessions, conclusions, and search within that workspace |
| **Peer** (`peer_id`) | Chat, representation, card, context, and search for that peer |
| **Session** (`session_id`) | Messages, context, summaries, and peer membership for that session |

A workspace-scoped key inherits access to all peers and sessions inside it.
A peer or session key only grants access to that specific resource.

At least one scope must be provided when creating a key.

## Creating scoped keys

### Basic usage

```elixir
# Admin client
admin = Honchox.new(api_key: "sk-admin-key")

# Create a workspace-scoped key
{:ok, %{"key" => jwt}} = Honchox.Keys.create(admin,
  workspace_id: "my-workspace"
)

# Use it in a new client
client = Honchox.new(jwt: jwt)
```

Note that when using `:jwt`, there is no need to pass `:base_url` if the
admin and scoped clients share the same Honcho instance and the `HONCHO_URL`
environment variable is set.

### Narrower scopes

```elixir
# Peer-scoped — can only access peer "alice" in this workspace
{:ok, %{"key" => jwt}} = Honchox.Keys.create(admin,
  workspace_id: "my-workspace",
  peer_id: "alice"
)

# Session-scoped — can only access this specific session
{:ok, %{"key" => jwt}} = Honchox.Keys.create(admin,
  workspace_id: "my-workspace",
  session_id: "session-1"
)

# All scopes combined — most restrictive
{:ok, %{"key" => jwt}} = Honchox.Keys.create(admin,
  workspace_id: "my-workspace",
  peer_id: "alice",
  session_id: "session-1"
)
```

## Expiration

Keys can have an expiration time. Once expired, any request using the key
returns `401 Unauthorized`.

### Relative expiration with `:expires_in`

Uses `{value, unit}` tuples, following the convention from libraries like
[Guardian](https://hexdocs.pm/guardian):

```elixir
# Expires in 1 hour
Honchox.Keys.create(admin,
  workspace_id: "my-workspace",
  expires_in: {1, :hour}
)

# Expires in 30 days
Honchox.Keys.create(admin,
  workspace_id: "my-workspace",
  expires_in: {30, :days}
)

# Expires in 15 minutes
Honchox.Keys.create(admin,
  workspace_id: "my-workspace",
  expires_in: {15, :minutes}
)
```

Supported units: `:second`, `:seconds`, `:minute`, `:minutes`, `:hour`,
`:hours`, `:day`, `:days`.

### Absolute expiration with `:expires_at`

```elixir
Honchox.Keys.create(admin,
  workspace_id: "my-workspace",
  expires_at: ~U[2026-12-31 23:59:59Z]
)
```

### No expiration

If neither `:expires_in` nor `:expires_at` is provided, the key **never
expires**. Use this carefully — the only way to invalidate a non-expiring key
is to rotate the `JWT_SECRET` on the server (which invalidates _all_ keys).

## Convenience: `create_client/2`

Instead of creating a key and then building a new client manually, use
`create_client/2`. It creates the scoped key and returns a ready-to-use
`%Honchox{}` client that inherits `base_url`, `timeout`, and `max_retries`
from the admin client:

```elixir
admin = Honchox.new(api_key: "sk-admin-key")

{:ok, client} = Honchox.Keys.create_client(admin,
  workspace_id: "my-workspace",
  expires_in: {1, :hour}
)

# Ready to use — no need to pass base_url or configure anything
{:ok, peers} = Honchox.Peers.list(client, workspace_id: "my-workspace")
```

## `api_key` vs `jwt`

`Honchox.new/1` accepts two authentication options:

| Option | Purpose | Env var fallback |
|--------|---------|------------------|
| `:api_key` | Admin/global key | `HONCHO_API_KEY` |
| `:jwt` | Scoped bearer token | *(none)* |

If both are provided, `:jwt` takes precedence. Typically you use `:api_key`
for the admin client and `:jwt` for scoped clients created via
`Honchox.Keys.create/2` or `Honchox.Keys.create_client/2`.

```elixir
# Admin client — full access
admin = Honchox.new(api_key: "sk-admin-key")

# Scoped client — restricted access
client = Honchox.new(jwt: "eyJ...")
```

## Practical example: frontend token delegation

A common pattern is minting a short-lived, workspace-scoped key for a frontend
application so it can read session context without having admin access:

```elixir
defmodule MyApp.HonchoTokens do
  def mint_frontend_token(workspace_id) do
    admin = Honchox.new()

    Honchox.Keys.create(admin,
      workspace_id: workspace_id,
      expires_in: {1, :hour}
    )
  end
end
```

The frontend receives the JWT and uses it directly in API calls. When it
expires, the frontend requests a new one through your backend.

## Limitations

- **No list/delete/rotate** — keys are stateless JWTs; the server does not
  track them. There is no endpoint to list or revoke individual keys.
- **No refresh** — create a new key instead of extending an existing one.
- **Admin only** — only clients authenticated with an admin key can create
  scoped keys. A scoped key cannot create other keys.
