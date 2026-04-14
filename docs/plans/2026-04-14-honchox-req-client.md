# Honchox Req Client Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an idiomatic Elixir client for the Honcho API using `Req`, with nearly full public coverage of the official TypeScript SDK and a `typesense_ex`-style API.

**Architecture:** `Honchox` is both the client struct and the low-level HTTP layer. Thin resource modules wrap explicit endpoint calls and return `{:ok, body}` or `{:error, %Honchox.Error{}}`, while tests use `Req.Test` to validate request shapes, retries, uploads, and error mapping without a live Honcho server.

**Tech Stack:** Elixir 1.19, Req, Req.Test, Jason, Plug, ExUnit

---

### Task 1: Add dependencies and baseline docs

**Files:**
- Modify: `mix.exs`
- Modify: `README.md`

**Step 1: Write the failing test**

Add a dependency-level smoke test in `test/honchox_test.exs` that asserts `Honchox.new/1` returns a client with a configured request field:

```elixir
test "new/1 builds a client with req defaults" do
  client = Honchox.new(api_key: "test", workspace_id: "ws")

  assert %Honchox{} = client
  assert %Req.Request{} = client.req
  assert client.workspace_id == "ws"
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/honchox_test.exs`
Expected: FAIL because `Honchox.new/1` and the new struct fields do not exist yet.

**Step 3: Write minimal implementation**

Update dependencies in `mix.exs`:

```elixir
{:req, "~> 0.5"},
{:jason, "~> 1.4"},
{:plug, "~> 1.0", only: :test}
```

Document the upcoming client style briefly in `README.md`.

**Step 4: Run test to verify it passes**

Run: `mix deps.get && mix test test/honchox_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add mix.exs mix.lock README.md test/honchox_test.exs lib/honchox.ex
git commit -m "build: add req-based client dependencies"
```

### Task 2: Build the root client and low-level HTTP helpers

**Files:**
- Modify: `lib/honchox.ex`
- Create: `lib/honchox/error.ex`
- Test: `test/honchox_test.exs`

**Step 1: Write the failing test**

Add tests for:

```elixir
test "new/1 uses explicit config over env vars"
test "get/3 sends bearer auth and query params"
test "post/3 sends json body"
test "delete/3 returns ok nil for empty 204"
```

Example:

```elixir
test "get/3 sends bearer auth and query params" do
  Req.Test.stub(HonchoxStub, fn conn ->
    assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
    assert conn.query_string == "page=1"
    Req.Test.json(conn, %{"ok" => true})
  end)

  client =
    Honchox.new(
      api_key: "secret",
      workspace_id: "ws",
      base_url: "https://api.honcho.dev",
      plug: {Req.Test, HonchoxStub}
    )

  assert {:ok, %{"ok" => true}} = Honchox.get(client, "/v3/workspaces", page: 1)
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/honchox_test.exs`
Expected: FAIL on missing helpers and error module.

**Step 3: Write minimal implementation**

Implement:

- `%Honchox{api_key, base_url, workspace_id, req, timeout, max_retries}`
- `new/1` with env fallbacks
- `get/3`, `post/3`, `put/3`, `patch/3`, `delete/3`, `upload/4`
- centralized response and error handling
- `%Honchox.Error{message, status, code, body, kind}`

**Step 4: Run test to verify it passes**

Run: `mix test test/honchox_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/honchox.ex lib/honchox/error.ex test/honchox_test.exs
git commit -m "feat: add root honcho client and error handling"
```

### Task 3: Add retry, timeout, and transport error coverage

**Files:**
- Modify: `lib/honchox.ex`
- Modify: `lib/honchox/error.ex`
- Test: `test/honchox_test.exs`

**Step 1: Write the failing test**

Add tests for:

```elixir
test "retries on 500 and succeeds on second attempt"
test "maps transport failures to transport errors"
test "maps timeout failures to timeout errors"
```

**Step 2: Run test to verify it fails**

Run: `mix test test/honchox_test.exs`
Expected: FAIL because retry and error mapping are incomplete or wrong.

**Step 3: Write minimal implementation**

Configure `Req` retry behavior to cover:

- `429`
- `500`
- `502`
- `503`
- `504`

Map timeout and transport failures into `%Honchox.Error{}`.

**Step 4: Run test to verify it passes**

Run: `mix test test/honchox_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/honchox.ex lib/honchox/error.ex test/honchox_test.exs
git commit -m "feat: add retry and transport error mapping"
```

### Task 4: Implement workspace resource module

**Files:**
- Create: `lib/honchox/workspaces.ex`
- Test: `test/honchox/workspaces_test.exs`

**Step 1: Write the failing test**

Add tests covering:

- `get_or_create/3`
- `update/3`
- `delete/2`
- `list/2`
- `search/3`
- `queue_status/2`
- `schedule_dream/2`

Example:

```elixir
test "get_or_create/3 posts to the workspace endpoint" do
  Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
    assert conn.method == "POST"
    assert conn.request_path == "/v3/workspaces"
    Req.Test.json(conn, %{"id" => "ws", "metadata" => %{}, "configuration" => %{}})
  end)

  client = Honchox.new(api_key: "secret", workspace_id: "ws", plug: {Req.Test, HonchoxWorkspacesStub})

  assert {:ok, %{"id" => "ws"}} =
           Honchox.Workspaces.get_or_create(client, "ws")
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/honchox/workspaces_test.exs`
Expected: FAIL because the module does not exist.

**Step 3: Write minimal implementation**

Implement the module as thin wrappers around `Honchox.get/post/put/delete`.

**Step 4: Run test to verify it passes**

Run: `mix test test/honchox/workspaces_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/honchox/workspaces.ex test/honchox/workspaces_test.exs
git commit -m "feat: add workspace endpoints"
```

### Task 5: Implement peers resource module

**Files:**
- Create: `lib/honchox/peers.ex`
- Test: `test/honchox/peers_test.exs`

**Step 1: Write the failing test**

Add tests covering:

- `get_or_create/3`
- `update/3`
- `list/2`
- `list_sessions/3`
- `chat/4`
- `search/4`
- `representation/3`
- `context/3`
- `get_card/3`
- `set_card/4`

Include one test that verifies query/body normalization for `reasoning_level`, `target`, and `session_id`.

**Step 2: Run test to verify it fails**

Run: `mix test test/honchox/peers_test.exs`
Expected: FAIL

**Step 3: Write minimal implementation**

Implement the peer endpoints with small private helpers to build the workspace-scoped paths and normalize option keys to API fields.

**Step 4: Run test to verify it passes**

Run: `mix test test/honchox/peers_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/honchox/peers.ex test/honchox/peers_test.exs
git commit -m "feat: add peer endpoints"
```

### Task 6: Implement sessions resource module

**Files:**
- Create: `lib/honchox/sessions.ex`
- Test: `test/honchox/sessions_test.exs`

**Step 1: Write the failing test**

Add tests covering:

- `get_or_create/3`
- `update/3`
- `delete/2`
- `clone/3`
- `context/3`
- `summaries/2`
- `search/4`
- `add_peers/3`
- `set_peers/3`
- `remove_peers/3`
- `list_peers/2`
- `get_peer_config/3`
- `set_peer_config/4`
- `add_messages/3`
- `list_messages/3`
- `get_message/3`
- `update_message/4`
- `upload_file/4`
- `queue_status/3`
- `representation/4`

Add at least one multipart upload test asserting the request is `multipart/form-data`.

**Step 2: Run test to verify it fails**

Run: `mix test test/honchox/sessions_test.exs`
Expected: FAIL

**Step 3: Write minimal implementation**

Implement the session module with lightweight parameter normalization and dedicated helpers for multipart file upload.

**Step 4: Run test to verify it passes**

Run: `mix test test/honchox/sessions_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/honchox/sessions.ex test/honchox/sessions_test.exs
git commit -m "feat: add session endpoints"
```

### Task 7: Implement conclusions and observations resource modules

**Files:**
- Create: `lib/honchox/conclusions.ex`
- Create: `lib/honchox/observations.ex`
- Test: `test/honchox/conclusions_test.exs`
- Test: `test/honchox/observations_test.exs`

**Step 1: Write the failing test**

Add tests covering:

- conclusion list, query, create, delete, representation
- observation list, query, delete

**Step 2: Run test to verify it fails**

Run: `mix test test/honchox/conclusions_test.exs test/honchox/observations_test.exs`
Expected: FAIL

**Step 3: Write minimal implementation**

Implement both modules as thin endpoint wrappers.

**Step 4: Run test to verify it passes**

Run: `mix test test/honchox/conclusions_test.exs test/honchox/observations_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/honchox/conclusions.ex lib/honchox/observations.ex test/honchox/conclusions_test.exs test/honchox/observations_test.exs
git commit -m "feat: add conclusions and observations endpoints"
```

### Task 8: Add doctests and README usage coverage

**Files:**
- Modify: `lib/honchox.ex`
- Modify: `lib/honchox/workspaces.ex`
- Modify: `lib/honchox/peers.ex`
- Modify: `lib/honchox/sessions.ex`
- Modify: `README.md`
- Test: `test/honchox_test.exs`

**Step 1: Write the failing test**

Add doctest coverage where practical and one README-aligned smoke test for basic client construction.

**Step 2: Run test to verify it fails**

Run: `mix test`
Expected: FAIL if docs and doctests are out of sync.

**Step 3: Write minimal implementation**

Add concise examples showing:

- `Honchox.new/1`
- peer creation
- session creation
- adding messages
- workspace search

**Step 4: Run test to verify it passes**

Run: `mix test`
Expected: PASS

**Step 5: Commit**

```bash
git add README.md lib/honchox.ex lib/honchox/workspaces.ex lib/honchox/peers.ex lib/honchox/sessions.ex test/honchox_test.exs
git commit -m "docs: add honchox usage examples"
```

### Task 9: Run full verification and cleanup

**Files:**
- Modify: any touched files if formatting or test fixes are needed

**Step 1: Write the failing test**

No new test in this task. Verification task only.

**Step 2: Run test to verify current state**

Run: `mix format --check-formatted`
Expected: PASS or a list of files needing formatting.

Run: `mix test`
Expected: PASS

**Step 3: Write minimal implementation**

If formatting fails:

```bash
mix format
```

If a small regression appears, fix the minimal code needed and re-run the relevant test first, then the full suite.

**Step 4: Run test to verify it passes**

Run: `mix format --check-formatted && mix test`
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "chore: finalize honchox req client"
```
