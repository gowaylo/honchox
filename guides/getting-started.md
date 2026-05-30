# Getting Started

This guide walks you through installing Honchox, configuring a client, and
making your first API calls to the Honcho v3 API.

## Installation

Add `honchox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:honchox, "~> 0.1.0"}
  ]
end
```

Then fetch the dependency:

```bash
mix deps.get
```

## Configuration

### API key

Honchox needs an API key to authenticate with the Honcho API. You can pass it
directly or set the `HONCHO_API_KEY` environment variable:

```bash
export HONCHO_API_KEY="sk-your-api-key"
```

### Creating a client

```elixir
# Reads HONCHO_API_KEY from the environment
client = Honchox.new()

# Or pass the key explicitly
client = Honchox.new(api_key: "sk-your-api-key")

# Custom base URL (e.g. for self-hosted or dev environments)
client = Honchox.new(
  api_key: "sk-your-api-key",
  base_url: "https://api.honcho.dev"
)
```

### Client options

| Option          | Default                                         | Description                                                                          |
|-----------------|-------------------------------------------------|--------------------------------------------------------------------------------------|
| `:api_key`      | `HONCHO_API_KEY` env var                        | Admin API key (required unless `:jwt`)                                               |
| `:jwt`          | *(none)*                                        | Scoped JWT token (see [Scoped Keys](scoped-keys.html))                               |
| `:base_url`     | `https://api.honcho.dev`                        | API base URL                                                                         |
| `:workspace_id` | `HONCHO_WORKSPACE_ID` env var, then `"default"` | Stored on `%Honchox.Client{}`; resource calls still require `:workspace_id` today     |
| `:timeout`      | `60_000`                                        | Receive timeout in ms                                                                |
| `:max_retries`  | `2`                                             | Retries on transient failures                                                        |

## Core concepts

### Workspaces

Workspaces are the top-level organizational unit. Every peer, session, and
conclusion belongs to a workspace.

```elixir
# Create or get a workspace
{:ok, workspace} = Honchox.Workspaces.get_or_create(client, "my-workspace",
  metadata: %{team: "platform"}
)
```

### Peers

Peers represent participants — users, agents, or any entity that interacts
within a workspace.

```elixir
# Create or get a peer
{:ok, peer} = Honchox.Peers.get_or_create(client, "alice",
  workspace_id: "my-workspace",
  metadata: %{role: "user"}
)
```

### Sessions

Sessions are conversation threads that contain messages and accumulate context.

```elixir
# Create a session
{:ok, session} = Honchox.Sessions.get_or_create(client, "session-1",
  workspace_id: "my-workspace",
  metadata: %{topic: "onboarding"}
)

# Add messages
{:ok, _msgs} = Honchox.Sessions.add_messages(client, "session-1", [
  %{peer_id: "alice", content: "Hello!"},
  %{peer_id: "bot", content: "Hi Alice! How can I help?"}
], workspace_id: "my-workspace")
```

### Conclusions

Conclusions are persistent observations about peers derived from conversations.

```elixir
# Create conclusions
{:ok, _} = Honchox.Conclusions.create(client, [
  %{
    content: "Prefers step-by-step explanations",
    observer_id: "bot",
    observed_id: "alice"
  }
], workspace_id: "my-workspace")

# Semantic search
{:ok, results} = Honchox.Conclusions.query(client, "learning preferences",
  workspace_id: "my-workspace",
  top_k: 5
)
```

## Workspace-scoped operations

Most resource operations are scoped to a workspace. Pass the `:workspace_id`
option on each call:

```elixir
# All of these require workspace_id
Honchox.Peers.list(client, workspace_id: "my-workspace")
Honchox.Sessions.list_messages(client, "session-1", workspace_id: "my-workspace")
Honchox.Conclusions.list(client, workspace_id: "my-workspace")
```

> Omitting `:workspace_id` raises an `ArgumentError`.

## Context and representation

One of Honcho's most powerful features is building context from accumulated
conversations and conclusions:

```elixir
# Get session context (summaries + conclusions + search)
{:ok, ctx} = Honchox.Sessions.context(client, "session-1",
  workspace_id: "my-workspace",
  search_query: "user preferences",
  search_top_k: 5
)

# Get a peer's representation
{:ok, repr} = Honchox.Peers.representation(client, "alice",
  workspace_id: "my-workspace"
)

# Chat with full peer context
{:ok, response} = Honchox.Peers.chat(client, "alice",
  "What do you remember about our conversations?",
  workspace_id: "my-workspace"
)
```

## Error handling

All functions return `{:ok, result}` or `{:error, %Honchox.Error{}}`:

```elixir
case Honchox.Peers.get_or_create(client, "alice", workspace_id: "ws") do
  {:ok, peer} ->
    IO.puts("Peer created: #{peer["id"]}")

  {:error, %Honchox.Error{kind: :http_error, status: 401}} ->
    IO.puts("Invalid API key")

  {:error, %Honchox.Error{kind: :timeout}} ->
    IO.puts("Request timed out")

  {:error, %Honchox.Error{} = error} ->
    IO.puts("Error: #{error.message}")
end
```

## Scoped keys

If you need to delegate limited access (e.g. to a frontend), you can create
scoped JWT keys from an admin client:

```elixir
admin = Honchox.new()

# Create a client restricted to one workspace, valid for 1 hour
{:ok, scoped} = Honchox.Keys.create_client(admin,
  workspace_id: "my-workspace",
  expires_in: {1, :hour}
)

# This client can only access "my-workspace"
{:ok, peers} = Honchox.Peers.list(scoped, workspace_id: "my-workspace")
```

See the [Scoped Keys](scoped-keys.html) guide for the full permission model
and usage patterns.

## Next steps

- Browse the [API Reference](api-reference.html) for all available functions
- Check the [Cheatsheet](cheatsheet.html) for a quick reference card
- Read the [Scoped Keys](scoped-keys.html) guide for delegated authentication
