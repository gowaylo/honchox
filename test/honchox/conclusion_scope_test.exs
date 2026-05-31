defmodule Honchox.ConclusionScopeTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "peer conclusions build scoped conclusion objects without HTTP" do
    peer = peer("alice")

    assert %{
             __struct__: Honchox.ConclusionScope,
             client: returned_client,
             workspace_id: "workspace-1",
             observer_id: "alice",
             observed_id: "alice"
           } = Honchox.Peer.conclusions(peer)

    assert returned_client == client()

    assert %{
             __struct__: Honchox.ConclusionScope,
             observer_id: "alice",
             observed_id: "bob"
           } = Honchox.Peer.conclusions_of(peer, %Honchox.Peer{id: "bob"})

    assert %{
             __struct__: Honchox.ConclusionScope,
             observer_id: "alice",
             observed_id: "bob"
           } = Honchox.Peer.conclusions_of(peer, "bob")
  end

  test "list/2 uses SDK request shape and returns a page of conclusion structs" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxConclusionScopeStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "size" => "10",
               "reverse" => "true"
             }

      assert conn.body_params == %{
               "filters" => %{
                 "observer_id" => "assistant",
                 "observed_id" => "alice",
                 "session_id" => "session-1"
               }
             }

      Req.Test.json(conn, %{
        "items" => [conclusion_api()],
        "total" => 1,
        "page" => 2,
        "size" => 10,
        "pages" => 1
      })
    end)

    scope = scope(observer_id: "assistant", observed_id: "alice")

    assert {:ok,
            %Honchox.Page{
              items: [
                %Honchox.Conclusion{
                  id: "c-1",
                  content: "Prefers concise answers",
                  observer_id: "assistant",
                  observed_id: "alice",
                  session_id: "session-1"
                }
              ],
              page: 2,
              size: 10
            }} =
             Honchox.ConclusionScope.list(scope,
               page: 2,
               size: 10,
               reverse: true,
               session: %Honchox.Session{id: "session-1"}
             )
  end

  test "query/3 omits distance by default and returns conclusion structs" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxConclusionScopeStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/query"

      assert conn.body_params == %{
               "query" => "preferences",
               "top_k" => 10,
               "filters" => %{"observer_id" => "assistant", "observed_id" => "alice"}
             }

      refute Map.has_key?(conn.body_params, "distance")

      Req.Test.json(conn, [conclusion_api()])
    end)

    assert {:ok, [%Honchox.Conclusion{id: "c-1"}]} =
             Honchox.ConclusionScope.query(
               scope(observer_id: "assistant", observed_id: "alice"),
               "preferences"
             )
  end

  test "create/2 scopes inputs and returns conclusion structs" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxConclusionScopeStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions"

      assert conn.body_params == %{
               "conclusions" => [
                 %{
                   "content" => "Prefers concise answers",
                   "observer_id" => "assistant",
                   "observed_id" => "alice",
                   "session_id" => "session-1"
                 },
                 %{
                   "content" => "Likes examples",
                   "observer_id" => "assistant",
                   "observed_id" => "alice",
                   "session_id" => nil
                 }
               ]
             }

      Req.Test.json(conn, [conclusion_api(), Map.put(conclusion_api(), "id", "c-2")])
    end)

    assert {:ok, [%Honchox.Conclusion{id: "c-1"}, %Honchox.Conclusion{id: "c-2"}]} =
             Honchox.ConclusionScope.create(
               scope(observer_id: "assistant", observed_id: "alice"),
               [
                 %{
                   content: "Prefers concise answers",
                   session: %Honchox.Session{id: "session-1"}
                 },
                 "Likes examples"
               ]
             )
  end

  test "create/2 accepts a single conclusion and still posts an array" do
    Req.Test.stub(HonchoxConclusionScopeStub, fn conn ->
      case conn.request_path do
        "/v3/workspaces" ->
          assert conn.method == "POST"
          Req.Test.json(conn, %{"id" => "workspace-1"})

        "/v3/workspaces/workspace-1/conclusions" ->
          assert conn.method == "POST"

          assert conn.body_params == %{
                   "conclusions" => [
                     %{
                       "content" => "Prefers concise answers",
                       "observer_id" => "assistant",
                       "observed_id" => "alice",
                       "session_id" => "session-1"
                     }
                   ]
                 }

          Req.Test.json(conn, [conclusion_api()])
      end
    end)

    assert {:ok, [%Honchox.Conclusion{id: "c-1"}]} =
             Honchox.ConclusionScope.create(
               scope(observer_id: "assistant", observed_id: "alice"),
               %{content: "Prefers concise answers", session: %Honchox.Session{id: "session-1"}}
             )
  end

  test "delete/2 ensures workspace and returns :ok" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxConclusionScopeStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/c-1"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert :ok = Honchox.ConclusionScope.delete(scope(), "c-1")
  end

  test "representation/2 uses peer-scoped SDK endpoint and returns representation string" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxConclusionScopeStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/assistant/representation"

      assert conn.body_params == %{
               "target" => "alice",
               "session_id" => "session-1",
               "search_query" => "preferences",
               "search_top_k" => 5
             }

      Req.Test.json(conn, %{"representation" => "Concise and direct."})
    end)

    assert {:ok, "Concise and direct."} =
             Honchox.ConclusionScope.representation(
               scope(observer_id: "assistant", observed_id: "alice"),
               session: %Honchox.Session{id: "session-1"},
               search_query: %Honchox.Message{content: "preferences"},
               search_top_k: 5
             )
  end

  test "legacy observations are not part of the SDK-shaped public API" do
    refute Code.ensure_loaded?(Honchox.Observations)
  end

  defp expect_workspace_ensure(response_attrs \\ %{"id" => "workspace-1"}) do
    Req.Test.expect(HonchoxConclusionScopeStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces"
      assert conn.body_params == Map.take(response_attrs, ["id", "metadata", "configuration"])

      Req.Test.json(conn, response_attrs)
    end)
  end

  defp scope(attrs \\ []) do
    Map.merge(
      %{
        __struct__: Honchox.ConclusionScope,
        client: client(),
        workspace_id: "workspace-1",
        observer_id: "assistant",
        observed_id: "assistant"
      },
      Map.new(attrs)
    )
  end

  defp peer(id) do
    %Honchox.Peer{id: id, workspace_id: "workspace-1", client: client()}
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxConclusionScopeStub},
      retry: false
    )
  end

  defp conclusion_api do
    %{
      "id" => "c-1",
      "content" => "Prefers concise answers",
      "observer_id" => "assistant",
      "observed_id" => "alice",
      "session_id" => "session-1",
      "created_at" => "2026-05-31T00:00:00Z"
    }
  end
end
