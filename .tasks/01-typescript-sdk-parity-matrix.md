# Task 01 — TypeScript SDK parity matrix

## Goal

Create the complete implementation checklist mapping `@honcho-ai/sdk` TypeScript behavior to Honchox Elixir behavior.

## Preconditions

- Update `tasks.md` and mark this task as in progress before starting.
- Use the TypeScript SDK as the source of truth.

## Steps

1. Fetch or inspect `@honcho-ai/sdk`.
2. Enumerate all public SDK concepts and methods:
   - `Honcho`
   - `Peer`
   - `Session`
   - `Message`
   - `Conclusions`
   - context/representation types
   - pagination
   - errors/streaming where public
3. For every method, record:
   - TypeScript method
   - Elixir function
   - HTTP method
   - path
   - query params
   - body shape
   - return value / return struct
   - notes about option translation
4. Save the matrix at:

```text
docs/plans/honcho-typescript-sdk-parity-matrix.md
```

## Acceptance criteria

- Matrix exists and covers all public TypeScript SDK methods.
- Context functions are explicitly mapped.
- Any SDK concept without an Elixir equivalent is listed as pending.
- `tasks.md` is updated when done.
