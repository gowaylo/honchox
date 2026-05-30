defmodule Honchox.API.ConclusionsTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "list/4 posts scoped filters with SDK pagination query" do
    Req.Test.stub(HonchoxAPIConclusionsStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "reverse" => "true",
               "size" => "10"
             }

      assert conn.body_params == %{
               "filters" => %{
                 "observer_id" => "bot",
                 "observed_id" => "alice",
                 "session_id" => "session-1"
               }
             }

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} =
             Honchox.API.Conclusions.list(client(), "bot", "alice",
               page: 2,
               size: 10,
               reverse: true,
               session_id: "session-1"
             )
  end

  test "query/5 posts scoped semantic query body" do
    Req.Test.stub(HonchoxAPIConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/query"

      assert conn.body_params == %{
               "query" => "preferences",
               "top_k" => 6,
               "distance" => 0.42,
               "filters" => %{"observer_id" => "bot", "observed_id" => "alice"}
             }

      Req.Test.json(conn, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} =
             Honchox.API.Conclusions.query(client(), "bot", "alice", "preferences",
               top_k: 6,
               distance: 0.42
             )
  end

  test "query/5 defaults top_k to SDK default when omitted" do
    Req.Test.stub(HonchoxAPIConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/query"

      assert conn.body_params == %{
               "query" => "preferences",
               "top_k" => 10,
               "filters" => %{"observer_id" => "bot", "observed_id" => "alice"}
             }

      Req.Test.json(conn, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} =
             Honchox.API.Conclusions.query(client(), "bot", "alice", "preferences")
  end

  test "create/5 includes session_id null when no session is supplied" do
    Req.Test.stub(HonchoxAPIConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions"

      assert conn.body_params == %{
               "conclusions" => [
                 %{
                   "content" => "Prefers concise answers",
                   "observer_id" => "bot",
                   "observed_id" => "alice",
                   "session_id" => nil
                 }
               ]
             }

      Req.Test.json(conn, [%{"id" => "conclusion-1"}])
    end)

    assert {:ok, [%{"id" => "conclusion-1"}]} =
             Honchox.API.Conclusions.create(client(), "bot", "alice", [
               "Prefers concise answers"
             ])
  end

  test "create/5 posts scoped conclusions" do
    Req.Test.stub(HonchoxAPIConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions"

      assert conn.body_params == %{
               "conclusions" => [
                 %{
                   "content" => "Prefers concise answers",
                   "observer_id" => "bot",
                   "observed_id" => "alice",
                   "session_id" => "session-1"
                 }
               ]
             }

      Req.Test.json(conn, [%{"id" => "conclusion-1"}])
    end)

    assert {:ok, [%{"id" => "conclusion-1"}]} =
             Honchox.API.Conclusions.create(client(), "bot", "alice", ["Prefers concise answers"],
               session_id: "session-1"
             )
  end

  test "delete/2 deletes conclusion by id" do
    Req.Test.stub(HonchoxAPIConclusionsStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/conclusion-1"
      assert conn.query_string == ""

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, nil} = Honchox.API.Conclusions.delete(client(), "conclusion-1")
  end

  test "representation/4 delegates to observer peer representation" do
    Req.Test.stub(HonchoxAPIConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/bot/representation"

      assert conn.body_params == %{
               "target" => "alice",
               "search_query" => "preferences",
               "search_top_k" => 5,
               "search_max_distance" => 0.5,
               "include_most_frequent" => true,
               "max_conclusions" => 8
             }

      Req.Test.json(conn, %{"representation" => "..."})
    end)

    assert {:ok, %{"representation" => "..."}} =
             Honchox.API.Conclusions.representation(client(), "bot", "alice",
               search_query: "preferences",
               search_top_k: 5,
               search_max_distance: 0.5,
               include_most_frequent: true,
               max_conclusions: 8
             )
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxAPIConclusionsStub},
      retry: false
    )
  end
end
