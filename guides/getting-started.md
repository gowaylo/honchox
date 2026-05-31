# Getting Started

This guide walks you through installing Honchox, configuring a client, and
making your first API calls to the Honcho v3 API.

## Installation

Add `honchox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:honchox, "~> 0.2.0"}
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

The client is stateless and immutable. Resource functions return structs that
carry the configured client and workspace context forward without mutating the
original client.

### Client options

| Option          | Default                                         | Description                                      |
|-----------------|-------------------------------------------------|--------------------------------------------------|
| `:api_key`      | `HONCHO_API_KEY` env var                        | Admin API key (required unless `:jwt`)           |
| `:jwt`          | *(none)*                                        | Scoped JWT token (see [Scoped Keys](scoped-keys.html)) |
| `:base_url`     | `https://api.honcho.dev`                        | API base URL                                     |
| `:workspace_id` | `HONCHO_WORKSPACE_ID` env var, then `"default"` | Workspace used by resource helpers               |
| `:timeout`      | `60_000`                                        | Receive timeout in ms                            |
| `:max_retries`  | `2`                                             | Retries on transient failures                    |

## Core workflow

Resource entry points start from a configured client and return resource
structs that carry the client and workspace context forward. Maps remain useful
for metadata, configuration, filters, and internal raw payloads, but primary
public domain values are structs and helper functions:

```elixir
client = Honchox.new(workspace_id: "my-workspace")

{:ok, workspace} = Honchox.workspace(client)
{:ok, alice} = Honchox.peer(client, "alice", metadata: %{role: "user"})
{:ok, bot} = Honchox.peer(client, "bot")
{:ok, session} = Honchox.session(client, "session-1", metadata: %{topic: "onboarding"})

:ok = Honchox.Session.add_peers(session, [alice, bot])

{:ok, _messages} =
  Honchox.Session.add_messages(session, [
    Honchox.Peer.message(alice, "Hello!"),
    Honchox.Peer.message(bot, "Hi Alice! How can I help?")
  ])
```

## Context and representation

Use the resource structs for context, representation, and chat operations:

```elixir
{:ok, ctx} = Honchox.Session.context(session, search_query: "user preferences")
{:ok, repr} = Honchox.Peer.representation(alice)
{:ok, response} = Honchox.Peer.chat(alice, "What do you remember about our conversations?")
```

## Error handling

All API calls return `{:ok, result}` or `{:error, %Honchox.Error{}}`:

```elixir
case Honchox.peer(client, "alice") do
  {:ok, peer} ->
    IO.puts("Peer ready: #{peer.id}")

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

{:ok, scoped} = Honchox.Keys.create_client(admin,
  workspace_id: "my-workspace",
  expires_in: {1, :hour}
)

{:ok, peers} = Honchox.peers(scoped)
```

See the [Scoped Keys](scoped-keys.html) guide for the full permission model
and usage patterns.

## Next steps

- Browse the [API Reference](api-reference.html) for all available functions
- Check the [Cheatsheet](cheatsheet.html) for a quick reference card
- Read the [Scoped Keys](scoped-keys.html) guide for delegated authentication
