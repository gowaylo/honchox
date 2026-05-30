defmodule Honchox.API.PeersTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "get_or_create/3 posts peer id and attrs" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers"
      assert conn.body_params == %{"id" => "alice", "metadata" => %{"role" => "user"}}

      Req.Test.json(conn, %{"id" => "alice"})
    end)

    assert {:ok, %{"id" => "alice"}} =
             Honchox.API.Peers.get_or_create(client(), "alice", metadata: %{role: "user"})
  end

  test "update/3 puts peer attrs" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice"
      assert conn.body_params == %{"configuration" => %{"observe_me" => true}}

      Req.Test.json(conn, %{"id" => "alice"})
    end)

    assert {:ok, %{"id" => "alice"}} =
             Honchox.API.Peers.update(client(), "alice", configuration: %{observe_me: true})
  end

  test "list/2 posts filters with SDK pagination query" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "1",
               "reverse" => "true",
               "size" => "10"
             }

      assert conn.body_params == %{"filters" => %{"active" => true}}

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} =
             Honchox.API.Peers.list(client(),
               page: 1,
               size: 10,
               reverse: true,
               filters: %{active: true}
             )
  end

  test "list_sessions/3 posts filters with SDK pagination query" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/sessions"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "3",
               "reverse" => "true",
               "size" => "5"
             }

      assert conn.body_params == %{"filters" => %{"topic" => "support"}}

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} =
             Honchox.API.Peers.list_sessions(client(), "alice",
               page: 3,
               size: 5,
               reverse: true,
               filters: %{topic: "support"}
             )
  end

  test "chat/4 posts non-streaming SDK body" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/chat"

      assert conn.body_params == %{
               "query" => "hello",
               "stream" => false,
               "target" => "bot",
               "session_id" => "session-1",
               "reasoning_level" => "medium"
             }

      Req.Test.json(conn, %{"content" => "hi"})
    end)

    assert {:ok, %{"content" => "hi"}} =
             Honchox.API.Peers.chat(client(), "alice", "hello",
               target: "bot",
               session_id: "session-1",
               reasoning_level: "medium"
             )
  end

  test "search/4 posts query body" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/search"

      assert conn.body_params == %{
               "query" => "prefs",
               "filters" => %{"kind" => "message"},
               "limit" => 4
             }

      Req.Test.json(conn, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} =
             Honchox.API.Peers.search(client(), "alice", "prefs",
               filters: %{kind: "message"},
               limit: 4
             )
  end

  test "representation/3 posts representation options" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/representation"

      assert conn.body_params == %{
               "target" => "bot",
               "session_id" => "session-1",
               "search_query" => "prefs",
               "search_top_k" => 5,
               "search_max_distance" => 0.7,
               "include_most_frequent" => true,
               "max_conclusions" => 12
             }

      Req.Test.json(conn, %{"representation" => "..."})
    end)

    assert {:ok, %{"representation" => "..."}} =
             Honchox.API.Peers.representation(client(), "alice",
               target: "bot",
               session_id: "session-1",
               search_query: "prefs",
               search_top_k: 5,
               search_max_distance: 0.7,
               include_most_frequent: true,
               max_conclusions: 12
             )
  end

  test "context/3 gets representation options as query without session_id" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/context"

      assert URI.decode_query(conn.query_string) == %{
               "target" => "bot",
               "search_query" => "prefs",
               "search_top_k" => "5",
               "search_max_distance" => "0.7",
               "include_most_frequent" => "true",
               "max_conclusions" => "12"
             }

      Req.Test.json(conn, %{"context" => []})
    end)

    assert {:ok, %{"context" => []}} =
             Honchox.API.Peers.context(client(), "alice",
               target: "bot",
               session_id: "session-1",
               search_query: "prefs",
               search_top_k: 5,
               search_max_distance: 0.7,
               include_most_frequent: true,
               max_conclusions: 12
             )
  end

  test "get_card/3 gets target query" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/card"
      assert URI.decode_query(conn.query_string) == %{"target" => "bot"}

      Req.Test.json(conn, %{"peer_card" => []})
    end)

    assert {:ok, %{"peer_card" => []}} =
             Honchox.API.Peers.get_card(client(), "alice", target: "bot")
  end

  test "set_card/4 puts target query and peer_card body" do
    Req.Test.stub(HonchoxAPIPeersStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/card"
      assert URI.decode_query(conn.query_string) == %{"target" => "bot"}
      assert conn.body_params == %{"peer_card" => ["concise", "technical"]}

      Req.Test.json(conn, %{"peer_card" => ["concise", "technical"]})
    end)

    assert {:ok, %{"peer_card" => ["concise", "technical"]}} =
             Honchox.API.Peers.set_card(client(), "alice", ["concise", "technical"],
               target: "bot"
             )
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxAPIPeersStub},
      retry: false
    )
  end
end
