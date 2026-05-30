defmodule Honchox.API.WorkspacesTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "get_or_create/3 posts workspace id and attrs" do
    Req.Test.stub(HonchoxAPIWorkspacesStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces"
      assert conn.body_params == %{"id" => "workspace-1", "metadata" => %{"team" => "sdk"}}

      Req.Test.json(conn, %{"id" => "workspace-1"})
    end)

    assert {:ok, %{"id" => "workspace-1"}} =
             Honchox.API.Workspaces.get_or_create(client(), "workspace-1",
               metadata: %{team: "sdk"}
             )
  end

  test "update/3 puts workspace attrs" do
    Req.Test.stub(HonchoxAPIWorkspacesStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1"
      assert conn.body_params == %{"configuration" => %{"dreams" => true}}

      Req.Test.json(conn, %{"id" => "workspace-1"})
    end)

    assert {:ok, %{"id" => "workspace-1"}} =
             Honchox.API.Workspaces.update(client(), "workspace-1",
               configuration: %{dreams: true}
             )
  end

  test "delete/2 deletes workspace" do
    Req.Test.stub(HonchoxAPIWorkspacesStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1"
      assert conn.query_string == ""

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, nil} = Honchox.API.Workspaces.delete(client(), "workspace-1")
  end

  test "list/2 posts filters with SDK pagination query" do
    Req.Test.stub(HonchoxAPIWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "reverse" => "true",
               "size" => "25"
             }

      assert conn.body_params == %{"filters" => %{"metadata.team" => "sdk"}}

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} =
             Honchox.API.Workspaces.list(client(),
               page: 2,
               size: 25,
               reverse: true,
               filters: %{"metadata.team" => "sdk"}
             )
  end

  test "search/3 posts query body to client workspace" do
    Req.Test.stub(HonchoxAPIWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/search"

      assert conn.body_params == %{
               "query" => "launch",
               "filters" => %{"kind" => "note"},
               "limit" => 3
             }

      Req.Test.json(conn, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} =
             Honchox.API.Workspaces.search(client(), "launch", filters: %{kind: "note"}, limit: 3)
  end

  test "queue_status/2 gets workspace queue filters" do
    Req.Test.stub(HonchoxAPIWorkspacesStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/queue/status"

      assert URI.decode_query(conn.query_string) == %{
               "observer_id" => "bot",
               "sender_id" => "alice",
               "session_id" => "session-1"
             }

      Req.Test.json(conn, %{"total_work_units" => 1})
    end)

    assert {:ok, %{"total_work_units" => 1}} =
             Honchox.API.Workspaces.queue_status(client(),
               observer_id: "bot",
               sender_id: "alice",
               session_id: "session-1"
             )
  end

  test "schedule_dream/2 sends SDK omni dream body" do
    Req.Test.stub(HonchoxAPIWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/schedule_dream"

      assert conn.body_params == %{
               "observer" => "bot",
               "observed" => "alice",
               "session_id" => "session-1",
               "dream_type" => "omni"
             }

      Req.Test.json(conn, %{"status" => "queued"})
    end)

    assert {:ok, %{"status" => "queued"}} =
             Honchox.API.Workspaces.schedule_dream(client(),
               observer_id: "bot",
               observed_id: "alice",
               session_id: "session-1"
             )
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxAPIWorkspacesStub},
      retry: false
    )
  end
end
