# Honchox

[![Hex.pm](https://img.shields.io/hexpm/v/honchox.svg)](https://hex.pm/packages/honchox)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/honchox)

Req-based Elixir client for the [Honcho](https://honcho.dev) v3 API.

Honchox wraps [Req](https://hexdocs.pm/req) with built-in authentication,
transient retry logic, and structured error handling to provide a struct-first
SDK-shaped interface to the Honcho API.

## Installation

Add `honchox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:honchox, "~> 0.2.0"}
  ]
end
```

## Quick start

```elixir
client = Honchox.new(workspace_id: "my-workspace")

{:ok, workspace} = Honchox.workspace(client)
{:ok, peer} = Honchox.peer(client, "alice", metadata: %{role: "user"})
{:ok, session} = Honchox.session(client, "session-1", metadata: %{topic: "onboarding"})

{:ok, _messages} = Honchox.Session.add_messages(session, [
  %{peer_id: peer.id, content: "Hello!"},
  %{peer_id: "bot", content: "Hi Alice, how can I help?"}
])

{:ok, response} = Honchox.Peer.chat(peer, "What should we do next?", session: session)
```

## Modules

| Module | Description |
|--------|-------------|
| `Honchox` | Client initialization and SDK-shaped entry points |
| `Honchox.Workspace` | Workspace struct |
| `Honchox.Peer` | Peer struct methods for chat, context, cards, search, and sessions |
| `Honchox.Session` | Session struct methods for messages, peers, context, and files |
| `Honchox.ConclusionScope` | Scoped conclusion CRUD and semantic search |
| `Honchox.Keys` | Scoped JWT creation and delegated authentication |
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

## Error handling

All functions return `{:ok, result}` or `{:error, %Honchox.Error{}}`.

```elixir
case Honchox.peer(client, "alice") do
  {:ok, peer} -> peer
  {:error, %Honchox.Error{kind: :http_error, status: status}} -> {:error, status}
end
```

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/honchox).

## License

MIT
