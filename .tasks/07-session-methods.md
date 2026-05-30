# Task 07 — Session methods

## Goal

Implement `Honchox.Session` behavior matching TypeScript SDK `Session` methods.

## Preconditions

- Tasks 01–05 complete.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD.

## Target function groups

### Lifecycle

```elixir
Honchox.Session.clone(session, opts \\ [])
Honchox.Session.delete(session)
```

### Peer membership

```elixir
Honchox.Session.add_peers(session, peers)
Honchox.Session.set_peers(session, peers)
Honchox.Session.remove_peers(session, peers)
Honchox.Session.peers(session)
Honchox.Session.get_peer_configuration(session, peer)
Honchox.Session.set_peer_configuration(session, peer, config)
```

### Messages

```elixir
Honchox.Session.add_messages(session, messages)
Honchox.Session.messages(session, opts \\ [])
Honchox.Session.get_message(session, message_id)
Honchox.Session.update_message(session, message_id, opts)
Honchox.Session.upload_file(session, file, opts \\ [])
```

### Context/search

```elixir
Honchox.Session.context(session, opts \\ [])
Honchox.Session.summaries(session)
Honchox.Session.search(session, query, opts \\ [])
Honchox.Session.queue_status(session, opts \\ [])
Honchox.Session.representation(session, peer, opts \\ [])
```

## Requirements

- Match TypeScript SDK endpoint behavior exactly.
- Return structs for known response types.
- Use workspace queue endpoint for session queue status.
- Use peer representation endpoint for session-scoped representation.
- Do not expose invented session representation endpoints.

## Acceptance criteria

- Split tests by lifecycle, membership, messages, and context/search if useful.
- All known previous divergences are corrected.
- No raw maps returned for known domain values.
- `tasks.md` is updated when done.
