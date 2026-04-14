# Honchox

Honchox is a Req-based Elixir client for the Honcho API.

The public entrypoint is `Honchox.new/1`, which returns a `%Honchox{}`
client struct with the workspace id and request defaults attached. Resource
modules will build on that client shape.

The client targets the Honcho v3 API under `/v3/...`.

## Quickstart

```elixir
client =
  Honchox.new(
    api_key: System.fetch_env!("HONCHO_API_KEY"),
    workspace_id: System.fetch_env!("HONCHO_WORKSPACE_ID"),
    base_url: System.get_env("HONCHO_URL", "https://api.honcho.dev")
  )

{:ok, peer} =
  Honchox.Peers.get_or_create(client, "alice",
    metadata: %{role: "user"}
  )

{:ok, session} =
  Honchox.Sessions.get_or_create(client, "session-1",
    metadata: %{topic: "launch"}
  )

{:ok, messages} =
  Honchox.Sessions.add_messages(client, "session-1", [
    %{peer_id: "alice", content: "hello"}
  ])

{:ok, results} =
  Honchox.Workspaces.search(client, "launch planning",
    limit: 5
  )
```

## Modules

- `Honchox.Workspaces` wraps workspace-scoped endpoints such as workspace lookup, search, queue status, and dream scheduling.
- `Honchox.Peers` wraps peer lifecycle, peer chat, peer context, representation, and peer card endpoints.
- `Honchox.Sessions` wraps session lifecycle, peer membership, message ingestion, context, search, and file uploads.
- `Honchox.Conclusions` wraps conclusion list/query/create/delete flows.
- `Honchox.Observations` provides backward-compatible wrappers over the renamed conclusion endpoints.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `honchox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:honchox, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/honchox>.
