# Task 04 — Structs and API response conversion

## Goal

Introduce struct-first public representations and conversion from raw API responses.

## Preconditions

- Task 01 complete.
- Task 02 complete.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD.

## Scope

Create structs such as:

```text
lib/honchox/workspace.ex
lib/honchox/peer.ex
lib/honchox/session.ex
lib/honchox/message.ex
lib/honchox/conclusion.ex
lib/honchox/page.ex
lib/honchox/peer_context.ex
lib/honchox/session_context.ex
```

## Requirements

- Public domain values should be structs, not maps.
- Maps are allowed for metadata, configuration, filters, request option bags, and internal raw API payloads.
- Add explicit `from_api` conversion functions.
- Use atom fields in structs.
- Preserve arbitrary metadata/configuration as maps.

## Example

```elixir
Honchox.Peer.from_api(client, workspace_id, api_map)
Honchox.Session.from_api(client, workspace_id, api_map)
Honchox.Message.from_api(api_map)
```

## Acceptance criteria

- Tests prove API maps become structs.
- Page/list responses become `%Honchox.Page{}` where appropriate.
- Public conversion does not leak raw maps except in allowed schemaless fields.
- `tasks.md` is updated when done.
