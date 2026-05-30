# Task 05 — Client entry points

## Goal

Implement SDK-style root entry points on `Honchox`.

## Preconditions

- Tasks 01–04 complete.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD.

## Target functions

```elixir
Honchox.new(opts \\ [])
Honchox.peer(client, id, opts \\ [])
Honchox.peers(client, opts \\ [])
Honchox.session(client, id, opts \\ [])
Honchox.sessions(client, opts \\ [])
Honchox.workspace(client, opts \\ [])
```

## Requirements

- Match TypeScript SDK semantics.
- Use client-level `workspace_id`.
- Ensure workspace exists before high-level peer/session operations.
- Remain stateless: no hidden memoization.
- Return structs, not raw maps.

## Tests

- `Honchox.peer/3` calls workspace ensure then peer create/get.
- `Honchox.session/3` calls workspace ensure then session create/get.
- List functions return `%Honchox.Page{}` with struct items.
- No public raw map return for known domain values.

## Acceptance criteria

- Root API is usable for the SDK quick-start flow.
- Functions return `{:ok, struct}` / `{:error, %Honchox.Error{}}`.
- `tasks.md` is updated when done.
