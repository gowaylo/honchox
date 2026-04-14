# Honchox Req Client Design

## Goal

Build an idiomatic Elixir client for the Honcho API using `Req`, modeled on the API coverage of the official TypeScript SDK while matching the public style used in `typesense_ex`.

## Design Summary

`Honchox` will be both the client struct and the low-level HTTP layer. `Honchox.new/1` will return a `%Honchox{}` containing the base URL, API key, workspace ID, and a preconfigured `%Req.Request{}` with bearer auth, JSON defaults, timeout, retry policy, and optional test plug injection.

The public API will be split across thin resource modules:

- `Honchox.Workspaces`
- `Honchox.Peers`
- `Honchox.Sessions`
- `Honchox.Conclusions`
- `Honchox.Observations`

Each resource module will expose explicit functions that accept the client struct as the first argument and return `{:ok, body}` or `{:error, reason}`.

## Public API Shape

The API should look like:

```elixir
client =
  Honchox.new(
    api_key: System.get_env("HONCHO_API_KEY"),
    workspace_id: "default",
    base_url: "https://api.honcho.dev"
  )

{:ok, peer} =
  Honchox.Peers.get_or_create(client, "alice", metadata: %{role: "user"})

{:ok, session} =
  Honchox.Sessions.get_or_create(client, "session-1")

{:ok, messages} =
  Honchox.Sessions.add_messages(client, "session-1", [
    %{peer_id: "alice", content: "hello"}
  ])
```

This follows the team pattern from `typesense_ex`: a simple root client struct plus focused modules per API area. Unlike `typesense_ex`, the client keeps a prebuilt `Req.Request` so auth, retry, timeout, and test transport are configured once.

## Module Responsibilities

### `Honchox`

Owns:

- `%Honchox{}` struct definition
- `new/1`
- low-level HTTP helpers such as `get/3`, `post/3`, `put/3`, `patch/3`, `delete/3`, `upload/4`
- shared request building and response handling

Likely struct fields:

```elixir
defstruct [
  :api_key,
  :base_url,
  :workspace_id,
  :req,
  :timeout,
  :max_retries
]
```

### `Honchox.Workspaces`

Covers:

- get-or-create workspace
- update workspace
- delete workspace
- list workspaces
- search workspace
- queue status
- schedule dream

### `Honchox.Peers`

Covers:

- get-or-create peer
- update peer
- list peers
- list sessions for a peer
- chat
- optional chat stream follow-up if `Req` streaming lands cleanly in v1
- search
- representation
- context
- get/set card
- metadata/configuration helpers

### `Honchox.Sessions`

Covers:

- get-or-create session
- update session
- delete session
- clone session
- context
- summaries
- search
- add/set/remove/list peers
- get/set peer config
- add/list/get/update messages
- upload file
- queue status
- representation helper scoped through session calls
- metadata/configuration helpers

### `Honchox.Conclusions`

Covers:

- list conclusions
- query conclusions
- create conclusion
- delete conclusion
- representation helper endpoint

### `Honchox.Observations`

Covers:

- list observations
- query observations
- delete observation

## HTTP Layer

The internal `Req` request should be configured with:

- `base_url`
- bearer auth from `api_key`
- JSON request/response handling
- timeout default `60_000`
- retry count default `2`
- retry policy aligned with the TS SDK for `429`, `500`, `502`, `503`, `504`

The TS SDK uses exponential backoff starting at `500ms`. In Elixir, we should prefer `Req` retry configuration instead of reimplementing a manual loop unless `Req` cannot express the same policy cleanly.

## Configuration

`Honchox.new/1` should accept:

- `:api_key`
- `:base_url`
- `:workspace_id`
- `:timeout`
- `:max_retries`
- `:headers`
- `:params`
- `:plug`

Environment fallbacks should mirror the TS SDK where sensible:

- `HONCHO_API_KEY`
- `HONCHO_WORKSPACE_ID`
- `HONCHO_URL`

The TS README mentions `HONCHO_BASE_URL`, but the SDK code uses `HONCHO_URL`. The Elixir client should document the actual supported env var explicitly instead of inheriting that ambiguity.

## Encoding and Naming

Public Elixir APIs should accept idiomatic atom-keyed options where that improves ergonomics, but payloads can remain plain maps and lists. Endpoint payloads should be normalized to the snake_case fields expected by the API.

Examples:

- `reasoning_level` stays snake_case at the HTTP boundary
- public functions may accept `peer_perspective`, `peer_target`, `limit_to_session`
- returned payloads stay as decoded maps from the API for v1

We should not introduce resource structs in v1. The SDK surface is large enough that maps keep the implementation smaller and closer to the team style.

## Return Contracts

Success:

- `{:ok, body}` for `2xx`
- `{:ok, nil}` for empty successful responses if an endpoint returns no body

Failure:

- `{:error, %Honchox.Error{...}}`

Suggested error struct:

```elixir
defmodule Honchox.Error do
  defexception [:message, :status, :code, :body, :kind]
end
```

Where:

- `kind: :http` for HTTP failures
- `kind: :transport` for connection failures
- `kind: :timeout` for request timeouts

This keeps the outward contract stable even if `Req` internals change.

## Pagination

Pagination responses should remain raw Honcho-style maps in v1:

```elixir
%{
  "items" => [...],
  "page" => 1,
  "size" => 20,
  "total" => 200,
  "pages" => 10
}
```

We should avoid inventing a pagination abstraction until there is a real caller need. Resource functions may accept `page`, `size`, `reverse`, and `filters` in options and pass them through in the expected split between query params and JSON body.

## Testing Strategy

Use `Req.Test`, not live integration tests, as the primary test approach.

Test setup pattern:

```elixir
setup :set_req_test_from_context
setup {Req.Test, :verify_on_exit!}
```

The client should accept a `plug:` option so tests can route requests through `Req.Test`.

We should cover:

- client construction and env fallback behavior
- headers, auth, base URL, query params
- JSON body encoding for each resource module
- empty body handling
- HTTP error mapping
- transport and timeout error mapping
- retry behavior for retryable statuses and transport errors
- multipart upload request shape

## File Layout

Planned source files:

- `lib/honchox.ex`
- `lib/honchox/error.ex`
- `lib/honchox/workspaces.ex`
- `lib/honchox/peers.ex`
- `lib/honchox/sessions.ex`
- `lib/honchox/conclusions.ex`
- `lib/honchox/observations.ex`

Planned test files:

- `test/honchox_test.exs`
- `test/honchox/workspaces_test.exs`
- `test/honchox/peers_test.exs`
- `test/honchox/sessions_test.exs`
- `test/honchox/conclusions_test.exs`
- `test/honchox/observations_test.exs`

## Dependencies

Expected `mix.exs` additions:

- `{:req, "~> 0.5"}`
- `{:jason, "~> 1.4"}`
- `{:plug, "~> 1.0", only: :test}`

`Req.Test` is part of `Req`, but using the plug test transport is simplest if `:plug` is available in test.

## Non-Goals for v1

- resource structs mirroring TS classes
- local metadata/configuration caching like the TS SDK
- automatic workspace memoization
- async iterator pagination
- forced streaming parity if the `Req` story is awkward

## Notes

This repository was not under version control when the design was approved. Git was initialized later in the session, so the design can now be committed locally.
