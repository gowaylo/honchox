# Honchox SDK Struct Restructure Plan

Date: 2026-05-30

## Purpose

Restructure Honchox from a mostly low-level HTTP wrapper that returns raw maps into an idiomatic Elixir SDK with stable structs, matching the official `@honcho-ai/sdk` TypeScript package one-for-one in concepts, API calls, endpoint behavior, and context functions, while using idiomatic Elixir interfaces and immutable/stateless client values.

This document is intended to persist across sessions. Future agents should treat it as the source of truth for the restructure unless superseded by a newer plan.

## Current Assessment

Honchox currently appears to have been implemented directly against the Honcho v3 HTTP API, not as a port of the TypeScript SDK architecture.

Evidence:

- `README.md` describes it as a “Req-based Elixir client for the Honcho v3 API”.
- `lib/honchox.ex` is a root client plus low-level HTTP helpers.
- Resource modules call raw API paths such as `/v3/workspaces/:workspace_id/peers`.
- Most public functions return `{:ok, map()}` or `{:error, %Honchox.Error{}}`.
- There are no SDK-style resource structs such as `Peer`, `Session`, `Message`, or `Conclusion` with behavior attached.

The official TypeScript SDK checked for comparison was:

```text
@honcho-ai/sdk@2.1.2
```

Fetched with:

```bash
mkdir -p /tmp/honcho-sdk
cd /tmp/honcho-sdk
npm pack @honcho-ai/sdk --silent
tar -xzf honcho-ai-sdk-2.1.2.tgz
```

Important SDK files inspected:

- `/tmp/honcho-sdk/package/dist/client.js`
- `/tmp/honcho-sdk/package/dist/peer.js`
- `/tmp/honcho-sdk/package/dist/session.js`
- `/tmp/honcho-sdk/package/dist/conclusions.js`
- `/tmp/honcho-sdk/package/dist/http/client.js`
- `/tmp/honcho-sdk/package/dist/api-version.js`

## Strategic Decision

No one is using this library yet, so backward compatibility is **not** a constraint.

The target is a one-for-one Elixir SDK equivalent of the TypeScript SDK, not a generic Honcho HTTP wrapper. Existing code may be kept only when it helps implement the SDK-compatible design. Any concepts, endpoints, modules, or helper functions that do not match the TypeScript SDK should be removed, rewritten, or moved out of the public API.

Implementation stance:

1. Use the TypeScript SDK as the behavioral source of truth.
2. Keep only the existing Req-based HTTP/error pieces that still fit the new SDK design.
3. Replace raw map-first public APIs with struct-first SDK APIs.
4. Discard compatibility shims unless they are useful internally.
5. Make every API call and every context-related function match the TypeScript SDK semantics one-for-one, translated into idiomatic Elixir naming and return conventions.
6. Prefer structs almost exclusively for public/external representations. Maps should be limited to internal transport, request payloads, raw API decoding, metadata/configuration bags, filters, and other intentionally schemaless data.

Rationale:

- There are no downstream users to protect.
- A clean SDK-shaped API is more valuable than preserving the current HTTP-wrapper design.
- Req already provides a good immutable request/client foundation, so the SDK should remain stateless rather than introducing mutable SDK object state.

## Target Public API Shape

The desired direction is SDK-like, using structs instead of maps for public workflows and external representations. If a value has a known concept in the SDK/domain, it should be represented by a struct.

Example target usage:

```elixir
client = Honchox.new(api_key: "sk-...", workspace_id: "my-workspace")

{:ok, alice} = Honchox.peer(client, "alice", metadata: %{role: "user"})
{:ok, bot} = Honchox.peer(client, "bot")
{:ok, session} = Honchox.session(client, "session-1")

:ok = Honchox.Session.add_peers(session, [alice, bot])

{:ok, messages} =
  Honchox.Session.add_messages(session, [
    Honchox.Peer.message(alice, "Hello"),
    Honchox.Peer.message(bot, "Hi!")
  ])

{:ok, answer} = Honchox.Peer.chat(alice, "What did we talk about?")
```

Primary structs to introduce:

```elixir
%Honchox.Client{}
%Honchox.Workspace{}
%Honchox.Peer{}
%Honchox.Session{}
%Honchox.Message{}
%Honchox.Conclusion{}
%Honchox.PeerContext{}
%Honchox.Page{}
```

Prefer a clear `%Honchox.Client{}` public client struct if that makes the SDK design cleaner. Keeping `%Honchox{}` is optional and should only be done if it improves ergonomics; backward compatibility is not required.

Public return values should generally be structs, not maps. Maps are acceptable only for intentionally open-ended fields such as metadata, configuration, filters, request options, and raw internal API payloads.

## Proposed Layering

```text
Honchox
  Public entry point: new/1, peer/2, session/2, peers/1, sessions/1, etc.

Honchox.Client
  Immutable client struct: api_key/jwt, base_url, workspace_id, req, timeout, retries, default headers/query.
  Do not store mutable workspace-ready state.

Honchox.HTTP
  Low-level request helpers and response/error normalization.
  Existing Honchox.get/post/put/delete/upload can delegate here.

Honchox.API.*
  Private or internal endpoint modules that return raw decoded API maps.
  These must be mechanically aligned with the TypeScript SDK endpoints and payloads.

Honchox.Workspace / Peer / Session / Message / Conclusion / Context structs
  Public SDK structs and behavior.
  Convert raw API maps into structs.
  Functions on these modules should correspond to TypeScript SDK methods.
```

## SDK Parity Rules

Use the TypeScript SDK as the contract. For every public TypeScript method, decide the Elixir equivalent by applying these rules:

1. Same concept and same API call.
2. Same endpoint, HTTP method, query parameters, and JSON/multipart body.
3. Same default values and environment variable fallbacks.
4. Same resource ownership model: client owns workspace id; peer/session structs carry client + workspace id + their id.
5. Same context semantics: functions named `context`, `representation`, `chat`, `search`, `card`, `summaries`, etc. should call the same SDK endpoints and shape responses in the same way.
6. Idiomatic Elixir names: use snake_case function names and atom keys/options, but do not invent new concepts.
7. Idiomatic Elixir results: use `{:ok, value}` / `{:error, %Honchox.Error{}}` for fallible API calls.
8. Stateless/immutable client: no hidden mutation, no process-global cache, no Agent/ETS memoization for SDK object state.
9. Struct-first public API: decoded API responses should be converted to structs before crossing the public boundary unless the data is intentionally schemaless.

## API Call and Context Function Mapping

This section should be expanded as implementation proceeds. Initial mapping from `@honcho-ai/sdk@2.1.2`:

### Client / workspace

- `new Honcho(options)` -> `Honchox.new/1` returning `%Honchox.Client{}` or equivalent.
- `honcho.peer(id, options)` -> `Honchox.peer(client, id, opts \\ [])`.
- `honcho.peers(params)` -> `Honchox.peers(client, opts \\ [])`.
- `honcho.session(id, options)` -> `Honchox.session(client, id, opts \\ [])`.
- `honcho.sessions(params)` -> `Honchox.sessions(client, opts \\ [])`.
- Workspace create/update/delete/list/search/queue/schedule dream should match SDK private/public behavior and endpoint shapes.

### Peer context functions

- `peer.chat(query, options)` -> `Honchox.Peer.chat(peer, query, opts \\ [])`.
  - Endpoint: `POST /v3/workspaces/:workspace_id/peers/:peer_id/chat`.
  - Body uses SDK fields: `query`, `stream: false`, `target`, `session_id`, `reasoning_level`.
  - TypeScript returns `response.content` or `null`; Elixir should return `{:ok, content_or_nil}`.
- `peer.chatStream(query, options)` -> later `Honchox.Peer.chat_stream/3`.
  - Endpoint: same chat endpoint with `stream: true` and SSE handling.
- `peer.search(query, options)` -> `Honchox.Peer.search/3`.
  - Endpoint: `POST /v3/workspaces/:workspace_id/peers/:peer_id/search`.
- `peer.representation(options)` / representation helpers -> `Honchox.Peer.representation/2`.
  - Endpoint: `POST /v3/workspaces/:workspace_id/peers/:peer_id/representation`.
- `peer.context(options)` -> `Honchox.Peer.context/2`.
  - Endpoint: `GET /v3/workspaces/:workspace_id/peers/:peer_id/context`.
  - Response should become a peer context struct if the SDK models it as such.
- `peer.getCard` / `peer.setCard` equivalents -> `Honchox.Peer.get_card/2`, `Honchox.Peer.set_card/3`.
  - Endpoints: `GET/PUT /v3/workspaces/:workspace_id/peers/:peer_id/card`.

### Session context functions

- `session.context(options)` -> `Honchox.Session.context(session, opts \\ [])`.
  - Endpoint: `GET /v3/workspaces/:workspace_id/sessions/:session_id/context`.
  - Query params must match SDK option translation exactly.
  - Response should become the Elixir equivalent of the SDK `SessionContext` object.
- `session.summaries()` -> `Honchox.Session.summaries/1`.
  - Endpoint: `GET /v3/workspaces/:workspace_id/sessions/:session_id/summaries`.
- `session.search(query, options)` -> `Honchox.Session.search/3`.
  - Endpoint: `POST /v3/workspaces/:workspace_id/sessions/:session_id/search`.
- `session.getPeerConfiguration` / `setPeerConfiguration` -> `get_peer_configuration` / `set_peer_configuration`.
- `session.addMessages`, `messages`, `getMessage`, `updateMessage`, `uploadFile` must mirror SDK endpoints and message structs.
- `session.queueStatus` equivalent should use workspace queue endpoint with `session_id` query, matching SDK behavior.
- Any session representation helper must use the SDK's peer representation endpoint with session scoping, not an invented session representation endpoint.

## Struct-First Representation Policy

Honchox should strongly prefer structs over maps for anything exposed as a domain value.

Use structs for:

- client
- workspace
- peer
- session
- message
- conclusion
- context objects
- representation objects
- peer cards, if their shape is known/stable
- paginated responses
- queue status, if its shape is known/stable
- errors

Maps are acceptable for:

- internal decoded JSON before conversion
- request bodies before they are sent
- metadata/configuration fields that are intentionally arbitrary
- filters and query option bags
- test assertions against raw HTTP payloads
- private `Honchox.API.*` return values before public conversion
- explicit escape hatches, if any, named clearly as raw/internal

Public functions should not return raw maps by default. If raw access is needed, make it explicit, for example via an internal API module or a clearly named `raw_*` function.

## Compatibility Findings To Address

The TypeScript SDK uses API version `v3` and default base URL:

```text
https://api.honcho.dev
```

Honchox currently defaults to:

```text
https://api.honcho.ai
```

Known or suspected divergences:

| Area | Current Honchox | TypeScript SDK behavior | Action |
| --- | --- | --- | --- |
| Base URL | `https://api.honcho.ai` | `https://api.honcho.dev` | Change default, keep env override. |
| Workspace ID | Passed per call | Stored on client, env fallback `HONCHO_WORKSPACE_ID`, default `default` | Add client-level workspace support. |
| Ensure workspace | Manual | SDK memoizes `POST /v3/workspaces` once per client instance before peer/session ops | Preserve the semantic guarantee without mutable state; stateless Elixir may call ensure per high-level operation unless a purely immutable alternative is introduced. |
| `Sessions.clone` | body params | query params | Fix request shape. |
| `Sessions.add_peers` | body `%{peers: peers}` | body is peer mapping/list directly | Verify with tests, then fix. |
| `Sessions.set_peers` | body `%{peers: peers}` | body is peer mapping/list directly | Verify with tests, then fix. |
| `Sessions.remove_peers` | query `peer_ids=a,b` | DELETE body is peer id array | Verify Req supports body with DELETE, then fix. |
| `Sessions.upload_file` | `/sessions/:id/files` | `/sessions/:id/messages/upload` | Fix path. |
| `Sessions.queue_status` | `/sessions/:id/queue/status` | `/workspaces/:ws/queue/status?session_id=:id` | Fix path/query. |
| `Sessions.representation` | `/sessions/:id/representation` | `/peers/:peer_id/representation` with session scoping | Redesign/fix. |
| `Conclusions.representation` | `/conclusions/representation` | Not present in SDK; representation is peer-scoped | Mark deprecated/suspect unless API docs confirm. |
| Streaming chat | Not implemented | SDK has `chatStream` using SSE | Later phase. |
| Validation | Minimal | SDK validates/coerces with zod and translates camelCase/snake_case | Add Elixir changesets/constructors gradually, not first. |

## First Implementation Phase: API Compatibility Baseline

Before adding structs, write tests that lock down the correct HTTP behavior. Do not make the API prettier until the underlying requests are known to be correct.

Use `Req.Test` or the existing test approach to assert:

- HTTP method
- path
- query string
- JSON body
- authorization header
- multipart path/body where relevant

Recommended first tests:

```text
test/honchox/compatibility/sessions_test.exs
```

Cover:

1. `clone/3` sends `message_id` as query params.
2. `add_peers/4` sends the peer mapping/list directly in the body.
3. `set_peers/4` sends the peer mapping/list directly in the body.
4. `remove_peers/4` sends peer ids in the DELETE body.
5. `upload_file/4` posts to `/messages/upload`.
6. `queue_status/3` calls workspace queue status with `session_id` query.
7. `representation/4` uses the peer representation endpoint with session scoping.

Then add tests for:

```text
test/honchox/compatibility/client_test.exs
test/honchox/compatibility/workspaces_test.exs
test/honchox/compatibility/peers_test.exs
test/honchox/compatibility/conclusions_test.exs
```

Client tests should cover:

- default base URL is `https://api.honcho.dev`
- explicit base URL wins over env
- `HONCHO_URL` fallback
- `workspace_id:` option
- `HONCHO_WORKSPACE_ID` fallback
- default workspace id is `default`

Follow TDD:

1. Write a failing test for one compatibility rule.
2. Run the smallest relevant test file and confirm red.
3. Implement the smallest fix.
4. Run the same test and confirm green.
5. Repeat.

## Second Phase: Client-Level Workspace Semantics

Add client-level workspace behavior before public structs.

Target behavior:

```elixir
client = Honchox.new(api_key: "sk", workspace_id: "acme")
client.workspace_id == "acme"
```

Fallback order:

1. explicit `workspace_id:` option
2. `HONCHO_WORKSPACE_ID`
3. `default`

High-level operations must provide the same semantic guarantee as the TypeScript SDK: workspace-scoped peer/session operations should ensure the workspace exists before the operation.

Stateless Elixir rule:

- Do not use process-global mutable state.
- Do not hide mutable readiness state in an Agent/ETS/cache just to mimic TypeScript object memoization.
- The simplest acceptable implementation is to call `POST /v3/workspaces` before each high-level peer/session operation that requires workspace readiness.
- If avoiding repeated ensures becomes important later, prefer an explicit immutable return shape such as `{:ok, ensured_client}` or an opt-in caller-managed mechanism, not hidden mutation.

## Third Phase: Public Structs

Introduce structs with conversion functions from raw API maps.

Suggested initial structs:

```elixir
defmodule Honchox.Peer do
  defstruct [:id, :workspace_id, :client, :metadata, :configuration, :created_at]
end

defmodule Honchox.Session do
  defstruct [:id, :workspace_id, :client, :metadata, :configuration, :created_at, :is_active]
end

defmodule Honchox.Message do
  defstruct [:id, :session_id, :peer_id, :content, :metadata, :created_at]
end
```

Conversion functions should be explicit and test-covered:

```elixir
Honchox.Peer.from_api(client, workspace_id, map)
Honchox.Session.from_api(client, workspace_id, map)
Honchox.Message.from_api(map)
```

Prefer atom keys in public structs, but preserve raw API maps only when needed through an explicit field or helper, not as the default interface.

## Fourth Phase: SDK-Style Entry Points

Add high-level entry points that become the primary public API. Existing plural raw-map modules may be deleted, renamed under `Honchox.API.*`, or kept private; preserving them publicly is not required.

Target root functions:

```elixir
Honchox.peer(client, id, opts \\ [])
Honchox.peers(client, opts \\ [])
Honchox.session(client, id, opts \\ [])
Honchox.sessions(client, opts \\ [])
Honchox.workspace(client, opts \\ [])
```

Target struct-module functions:

```elixir
Honchox.Peer.chat(peer, query, opts \\ [])
Honchox.Peer.context(peer, opts \\ [])
Honchox.Peer.representation(peer, opts \\ [])
Honchox.Peer.message(peer, content, opts \\ [])

Honchox.Session.add_peers(session, peers)
Honchox.Session.set_peers(session, peers)
Honchox.Session.remove_peers(session, peers)
Honchox.Session.peers(session)
Honchox.Session.add_messages(session, messages)
Honchox.Session.messages(session, opts \\ [])
Honchox.Session.context(session, opts \\ [])
```

The older plural modules are not part of the target public SDK unless they map cleanly to TypeScript SDK concepts. Prefer moving raw endpoint wrappers under private/internal `Honchox.API.*` modules.

## Compatibility Policy

Backward compatibility with the current Honchox API is **not required**.

- Public behavior should optimize for one-for-one parity with `@honcho-ai/sdk`.
- Existing `Honchox.Peers.*`, `Honchox.Sessions.*`, etc. may be removed or rewritten.
- Raw maps should not be the primary public return type where the TypeScript SDK returns resource objects.
- Endpoints not present in the TypeScript SDK should not remain public unless there is a deliberate, documented reason.
- Per-call `workspace_id` should not be the primary interface; workspace belongs to the client/resource structs.

Known concepts likely to remove or redesign:

- `Honchox.Conclusions.representation/2` if current SDK/API confirms representation is peer-scoped only.
- Session representation endpoint if invalid.
- Any helper that exists only because the current library was an HTTP wrapper rather than an SDK.

## Testing Strategy

Use tests at three levels:

1. Compatibility endpoint tests
   - Assert exact request shape compared with TypeScript SDK behavior.

2. Struct conversion tests
   - Assert raw API responses become typed structs.

3. High-level SDK workflow tests
   - Simulate a workflow: client -> peer -> session -> messages -> chat/context.

Avoid live API calls in unit tests. Use `Req.Test` or equivalent stubs.

## Documentation Updates

After each phase, update:

- `README.md`
- `guides/getting-started.md`
- `guides/cheatsheet.cheatmd`
- module docs in `lib/`

The docs should lead with the SDK-style struct API once it exists, while keeping a section for low-level/raw API usage.

## Recommended Immediate Next Task

Start with the compatibility baseline for `Honchox.Sessions`, because it has the highest number of known divergences.

Concrete next task:

1. Create `test/honchox/compatibility/sessions_test.exs`.
2. Add one failing test for `Sessions.clone/3` verifying query params instead of JSON body.
3. Run only that test file and confirm failure.
4. Fix `Sessions.clone/3`.
5. Continue with add/set/remove peers, upload, queue status, and representation.

## Open Questions

- Should `%Honchox{}` remain the public client struct, or should a new `%Honchox.Client{}` be introduced with `%Honchox{}` delegating for compatibility?
- Should the public API use snake_case options only, or accept camelCase aliases to mirror TypeScript concepts?
- Should struct fields include a raw API response for forward compatibility?
- How much validation should be added in Elixir versus trusting the API?
- Which TypeScript SDK methods should return plain strings/nil versus Elixir structs or tagged tuples?
