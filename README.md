# Honchox

[![Hex.pm](https://img.shields.io/hexpm/v/honchox.svg)](https://hex.pm/packages/honchox)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/honchox)

Req-based Elixir client for the [Honcho](https://honcho.dev) v3 API.

Honchox wraps [Req](https://hexdocs.pm/req) with built-in authentication,
transient retry logic, and structured error handling to provide a clean
interface to the Honcho API.

## Installation

Add `honchox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:honchox, "~> 0.1.0"}
  ]
end
```

## Quick start

```elixir
# Create a client (reads HONCHO_API_KEY from env)
client = Honchox.new()

# Create a peer in a workspace
{:ok, peer} = Honchox.Peers.get_or_create(client, "alice",
  workspace_id: "my-workspace",
  metadata: %{role: "user"}
)

# Start a session
{:ok, session} = Honchox.Sessions.get_or_create(client, "session-1",
  workspace_id: "my-workspace",
  metadata: %{topic: "onboarding"}
)

# Add messages
{:ok, _msgs} = Honchox.Sessions.add_messages(client, "session-1", [
  %{peer_id: "alice", content: "Hello!"},
  %{peer_id: "bot", content: "Hi Alice, how can I help?"}
], workspace_id: "my-workspace")

# Search across the workspace
{:ok, results} = Honchox.Workspaces.search(client, "onboarding",
  workspace_id: "my-workspace",
  limit: 5
)
```

## Modules

| Module | Description |
|--------|-------------|
| `Honchox` | Client initialization and low-level HTTP methods |
| `Honchox.Workspaces` | Workspace lifecycle, search, queue status, dream scheduling |
| `Honchox.Peers` | Peer lifecycle, chat, context, representation, cards |
| `Honchox.Sessions` | Session lifecycle, messages, peer membership, context, files |
| `Honchox.Conclusions` | Conclusion CRUD and semantic search |
| `Honchox.Keys` | Scoped JWT creation and delegated authentication |
| `Honchox.Observations` | *(deprecated)* Backward-compatible aliases for conclusions |
| `Honchox.Error` | Structured error with kind, status, and body |

## Configuration

| Option         | Env var          | Default                  |
|----------------|------------------|--------------------------|
| `:api_key`     | `HONCHO_API_KEY` | *(required unless `:jwt`)* |
| `:jwt`         | —                | *(scoped bearer token)*  |
| `:base_url`    | `HONCHO_URL`     | `https://api.honcho.dev`  |
| `:workspace_id`| `HONCHO_WORKSPACE_ID` | `default`          |
| `:timeout`     | —                | `60_000` ms              |
| `:max_retries` | —                | `2`                      |

```elixir
client = Honchox.new(
  api_key: "sk-...",
  base_url: "https://api.honcho.dev",
  timeout: 30_000,
  max_retries: 3
)
```

## Error handling

All functions return `{:ok, result}` or `{:error, %Honchox.Error{}}`.
Pattern match on the error `:kind` for granular handling:

```elixir
case Honchox.Peers.get_or_create(client, "alice", workspace_id: "ws") do
  {:ok, peer} ->
    peer

  {:error, %Honchox.Error{kind: :http_error, status: status}} ->
    Logger.error("HTTP #{status}")

  {:error, %Honchox.Error{kind: :timeout}} ->
    Logger.warning("Request timed out, retrying...")

  {:error, %Honchox.Error{kind: :transport, message: msg}} ->
    Logger.error("Network error: #{msg}")
end
```

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/honchox).

To generate docs locally:

```bash
mix docs
open doc/index.html
```

## License

MIT
