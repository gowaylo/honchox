# Task 06 — Peer methods

## Goal

Implement `Honchox.Peer` behavior matching TypeScript SDK `Peer` methods.

## Preconditions

- Tasks 01–05 complete.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD.

## Target functions

```elixir
Honchox.Peer.message(peer, content, opts \\ [])
Honchox.Peer.chat(peer, query, opts \\ [])
Honchox.Peer.chat_stream(peer, query, opts \\ []) # may be deferred if documented
Honchox.Peer.search(peer, query, opts \\ [])
Honchox.Peer.representation(peer, opts \\ [])
Honchox.Peer.context(peer, opts \\ [])
Honchox.Peer.get_card(peer, opts \\ [])
Honchox.Peer.set_card(peer, card, opts \\ [])
```

## Requirements

- Match SDK endpoints and payloads exactly.
- Translate Elixir snake_case options to SDK/API fields.
- Return structs for known response types.
- `chat/3` should return `{:ok, content_or_nil}` to match SDK `response.content || null` semantics.
- `message/3` should build a message input/value according to SDK behavior.

## Acceptance criteria

- Every implemented method has request-shape tests.
- Context/representation/card returns are struct-first when shape is known.
- Streaming is implemented or explicitly left as a documented follow-up.
- `tasks.md` is updated when done.
