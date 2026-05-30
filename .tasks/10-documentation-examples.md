# Task 10 — Documentation and examples

## Goal

Update all project documentation to describe the new SDK-style, struct-first API.

## Preconditions

- Main SDK API implemented.
- Update `tasks.md` and mark this task as in progress before starting.

## Files to update

```text
README.md
guides/getting-started.md
guides/cheatsheet.cheatmd
lib/**/*.ex module docs
```

## Requirements

- Lead with struct-first SDK examples.
- Mirror TypeScript SDK concepts in Elixir idioms.
- Document stateless/immutable client behavior.
- Document that maps are used for metadata/configuration/filters and internal raw payloads, not primary public domain values.
- Remove old examples that use raw map-first APIs unless explicitly marked internal/legacy.

## Example documentation flow

```elixir
client = Honchox.new(api_key: System.fetch_env!("HONCHO_API_KEY"), workspace_id: "default")

{:ok, assistant} = Honchox.peer(client, "assistant")
{:ok, alice} = Honchox.peer(client, "alice")
{:ok, session} = Honchox.session(client, "session_1")

:ok = Honchox.Session.add_peers(session, [alice, assistant])
```

## Acceptance criteria

- README quick start uses new API.
- Guides are consistent with code.
- Module docs compile.
- `mix docs` succeeds if available.
- `tasks.md` is updated when done.
