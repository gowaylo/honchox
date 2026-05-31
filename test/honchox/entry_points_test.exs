defmodule Honchox.EntryPointsTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "workspace/2 ensures the client workspace and returns a workspace struct" do
    client = client()

    expect_workspace_ensure(%{
      "id" => "workspace-1",
      "metadata" => %{"tier" => "test"},
      "configuration" => %{"mode" => "sdk"}
    })

    assert {:ok, %Honchox.Workspace{} = workspace} =
             Honchox.workspace(client,
               metadata: %{tier: "test"},
               configuration: %{mode: "sdk"}
             )

    assert workspace.id == "workspace-1"
    assert workspace.client == client
    refute Map.has_key?(workspace, "id")
  end

  test "peer/3 ensures workspace before get-or-create and returns a peer struct" do
    client = client()

    expect_workspace_ensure()

    Req.Test.expect(HonchoxEntryPointsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers"
      assert conn.body_params == %{"id" => "alice", "metadata" => %{"role" => "user"}}

      Req.Test.json(conn, %{
        "id" => "alice",
        "metadata" => %{"role" => "user"},
        "created_at" => "2026-05-31T00:00:00Z"
      })
    end)

    assert {:ok, %Honchox.Peer{} = peer} =
             Honchox.peer(client, "alice", metadata: %{role: "user"})

    assert peer.id == "alice"
    assert peer.workspace_id == "workspace-1"
    assert peer.client == client
    assert peer.metadata == %{"role" => "user"}
    refute Map.has_key?(peer, "id")
  end

  test "session/3 ensures workspace before get-or-create and returns a session struct" do
    client = client()

    expect_workspace_ensure()

    Req.Test.expect(HonchoxEntryPointsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions"

      assert conn.body_params == %{
               "id" => "session-1",
               "metadata" => %{"topic" => "support"},
               "peers" => [%{"peer_id" => "alice"}]
             }

      Req.Test.json(conn, %{
        "id" => "session-1",
        "metadata" => %{"topic" => "support"},
        "is_active" => true
      })
    end)

    assert {:ok, %Honchox.Session{} = session} =
             Honchox.session(client, "session-1",
               metadata: %{topic: "support"},
               peers: [%{peer_id: "alice"}]
             )

    assert session.id == "session-1"
    assert session.workspace_id == "workspace-1"
    assert session.client == client
    assert session.is_active == true
    refute Map.has_key?(session, "id")
  end

  test "peers/2 ensures workspace and returns a page of peer structs" do
    client = client()

    expect_workspace_ensure()

    Req.Test.expect(HonchoxEntryPointsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "reverse" => "true",
               "size" => "10"
             }

      assert conn.body_params == %{"filters" => %{"role" => "user"}}

      Req.Test.json(conn, %{
        "items" => [%{"id" => "alice", "metadata" => %{"role" => "user"}}],
        "total" => 1,
        "page" => 2,
        "size" => 10,
        "pages" => 1
      })
    end)

    assert {:ok, %Honchox.Page{} = page} =
             Honchox.peers(client,
               page: 2,
               size: 10,
               reverse: true,
               filters: %{role: "user"}
             )

    assert page.total == 1
    assert [%Honchox.Peer{id: "alice", workspace_id: "workspace-1", client: ^client}] = page.items
  end

  test "sessions/2 ensures workspace and returns a page of session structs" do
    client = client()

    expect_workspace_ensure()

    Req.Test.expect(HonchoxEntryPointsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/list"
      assert URI.decode_query(conn.query_string) == %{"page" => "1", "size" => "5"}
      assert conn.body_params == %{"filters" => %{"metadata.topic" => "support"}}

      Req.Test.json(conn, %{
        "items" => [%{"id" => "session-1", "is_active" => true}],
        "total" => 1,
        "page" => 1,
        "size" => 5,
        "pages" => 1
      })
    end)

    assert {:ok, %Honchox.Page{} = page} =
             Honchox.sessions(client,
               page: 1,
               size: 5,
               filters: %{"metadata.topic" => "support"}
             )

    assert page.pages == 1

    assert [%Honchox.Session{id: "session-1", workspace_id: "workspace-1", client: ^client}] =
             page.items
  end

  defp expect_workspace_ensure(response_attrs \\ %{"id" => "workspace-1"}) do
    Req.Test.expect(HonchoxEntryPointsStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces"
      assert conn.body_params == Map.take(response_attrs, ["id", "metadata", "configuration"])

      Req.Test.json(conn, response_attrs)
    end)
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxEntryPointsStub},
      retry: false
    )
  end
end
