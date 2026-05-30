# Task 02 — Stateless client and HTTP foundation

## Goal

Create the new stateless client foundation for the SDK-style API.

## Preconditions

- Task 01 complete or sufficiently drafted.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD: failing test first, red, implementation, green.

## Scope

Create/reorganize:

```text
lib/honchox/client.ex
lib/honchox/http.ex
lib/honchox/error.ex
```

## Target behavior

```elixir
client = Honchox.new(api_key: "sk", workspace_id: "ws")

%Honchox.Client{
  api_key: "sk",
  workspace_id: "ws",
  base_url: "https://api.honcho.dev",
  req: %Req.Request{}
}
```

## Requirements

- Default base URL: `https://api.honcho.dev`.
- Env fallback: `HONCHO_URL`.
- Workspace fallback order:
  1. explicit `workspace_id:`
  2. `HONCHO_WORKSPACE_ID`
  3. `default`
- Bearer auth.
- Timeout and retry options compatible with SDK defaults.
- No mutable readiness cache.
- No Agent/ETS/process-global state.

## Acceptance criteria

- Tests cover default/env/explicit config.
- Tests cover auth header and basic request helpers.
- Public client is a struct.
- `tasks.md` is updated when done.
