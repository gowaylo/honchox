# Task 09 — Remove or privatize old raw-map API

## Goal

Clean up the old HTTP-wrapper API now that the SDK-style API exists.

## Preconditions

- Tasks 01–08 complete or all public replacements implemented.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD where behavior changes are involved.

## Scope

Review old modules:

```text
Honchox.Workspaces
Honchox.Peers
Honchox.Sessions
Honchox.Conclusions
Honchox.Observations
Honchox.PeerWorkspaceQA
```

## Requirements

- Remove public modules/functions that do not match the TypeScript SDK.
- Move raw endpoint wrappers to `Honchox.API.*` if needed internally.
- Keep only SDK-shaped public modules and functions.
- Remove docs/examples for old raw-map workflows.

## Acceptance criteria

- Public API is struct-first and SDK-shaped.
- No old raw-map API is promoted in docs.
- Compile warnings are resolved.
- Test suite passes.
- `tasks.md` is updated when done.
