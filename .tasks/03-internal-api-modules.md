# Task 03 — Internal API modules matching TypeScript SDK

## Goal

Implement internal raw endpoint modules that match the TypeScript SDK one-for-one.

## Preconditions

- Task 01 complete.
- Task 02 complete.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD.

## Scope

Create internal modules:

```text
lib/honchox/api/workspaces.ex
lib/honchox/api/peers.ex
lib/honchox/api/sessions.ex
lib/honchox/api/conclusions.ex
```

These modules may return raw decoded maps because they are internal transport/API boundary modules.

## Requirements

- Every function maps to a TypeScript SDK API call.
- Request method/path/query/body match the SDK exactly.
- Do not expose these modules as the primary public API.
- Do not keep endpoints/concepts that are not in the SDK unless explicitly documented as internal.

## Tests

Create compatibility tests under:

```text
test/honchox/api/
```

Tests should assert:

- HTTP method
- path
- query string
- JSON or multipart body
- auth when relevant

## Acceptance criteria

- Sessions divergences are fixed first: clone, add/set/remove peers, upload, queue status, representation.
- All mapped API calls have request-shape tests.
- `tasks.md` is updated when done.
