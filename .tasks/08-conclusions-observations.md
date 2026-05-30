# Task 08 — Conclusions and legacy Observations decision

## Goal

Implement conclusions support only insofar as it matches the current TypeScript SDK, and decide what to do with legacy Observations.

## Preconditions

- Task 01 complete.
- Struct policy from Task 04 in place.
- Update `tasks.md` and mark this task as in progress before starting.
- Follow TDD.

## Requirements

- Map TypeScript SDK conclusions behavior one-for-one.
- Return `%Honchox.Conclusion{}` or `%Honchox.Page{}` as appropriate.
- Remove, privatize, or explicitly document legacy `Observations` if it is not part of the SDK.
- Remove or redesign `Conclusions.representation` if SDK/API parity shows representation is peer-scoped instead.

## Tests

- Request shape tests for each conclusions endpoint.
- Struct conversion tests for conclusions.
- Test proving unsupported legacy concepts are not part of the primary public API.

## Acceptance criteria

- Conclusions behavior matches SDK matrix.
- Observations decision is documented in the plan or docs.
- No public raw maps for conclusion domain values.
- `tasks.md` is updated when done.
