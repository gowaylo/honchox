defmodule Honchox.WorkspacesTest do
  use ExUnit.Case
  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "get_or_create/3 posts the workspace id and configuration payload" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces"

      assert %{
               "configuration" => %{"dream" => %{"enabled" => true}},
               "id" => "workspace-1",
               "metadata" => %{"team" => "alpha"}
             } = conn.body_params

      Req.Test.json(conn, %{"id" => "workspace-1"})
    end)

    client = client()

    assert {:ok, %{"id" => "workspace-1"}} =
             Honchox.Workspaces.get_or_create(client, "workspace-1",
               metadata: %{team: "alpha"},
               configuration: %{dream: %{enabled: true}}
             )
  end

  test "update/3 patches the workspace resource without an id in the body" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1"

      assert %{
               "configuration" => %{"summary" => %{"enabled" => false}},
               "metadata" => %{"team" => "beta"}
             } = conn.body_params

      refute Map.has_key?(conn.body_params, "id")

      Req.Test.json(conn, %{"id" => "workspace-1"})
    end)

    client = client()

    assert {:ok, %{"id" => "workspace-1"}} =
             Honchox.Workspaces.update(client, "workspace-1",
               metadata: %{team: "beta"},
               configuration: %{summary: %{enabled: false}}
             )
  end

  test "delete/2 deletes the workspace by id" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1"

      Plug.Conn.send_resp(conn, 202, "")
    end)

    client = client()

    assert {:ok, _body} = Honchox.Workspaces.delete(client, "workspace-1")
  end

  test "list/2 posts filters and pagination to the list endpoint" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/list"
      assert URI.decode_query(conn.query_string) == %{"page" => "2", "size" => "10"}
      assert conn.body_params == %{"filters" => %{"status" => "active"}}

      Req.Test.json(conn, %{"items" => [], "page" => 2, "size" => 10, "total" => 0, "pages" => 0})
    end)

    client = client()

    assert {:ok, %{"page" => 2}} =
             Honchox.Workspaces.list(client, page: 2, size: 10, filters: %{status: "active"})
  end

  test "list/2 also accepts map opts" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/list"
      assert URI.decode_query(conn.query_string) == %{"page" => "3", "size" => "25"}
      assert conn.body_params == %{"filters" => %{"status" => "draft"}}

      Req.Test.json(conn, %{"items" => [], "page" => 3, "size" => 25, "total" => 0, "pages" => 0})
    end)

    client = client()

    assert {:ok, %{"page" => 3}} =
             Honchox.Workspaces.list(client, %{page: 3, size: 25, filters: %{status: "draft"}})
  end

  test "search/3 scopes the query to the current workspace and sends filters" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/search"

      assert %{
               "filters" => %{"metadata" => %{"team" => "alpha"}},
               "limit" => 5,
               "query" => "budget planning"
             } = conn.body_params

      Req.Test.json(conn, [%{"id" => "msg-1"}])
    end)

    client = client()

    assert {:ok, [%{"id" => "msg-1"}]} =
             Honchox.Workspaces.search(client, "budget planning",
               filters: %{metadata: %{team: "alpha"}},
               limit: 5
             )
  end

  test "queue_status/2 passes workspace-scoped query params" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/queue/status"

      assert URI.decode_query(conn.query_string) == %{
               "observer_id" => "obs-1",
               "sender_id" => "peer-1",
               "session_id" => "session-1"
             }

      Req.Test.json(conn, %{
        "completed_work_units" => 1,
        "in_progress_work_units" => 0,
        "pending_work_units" => 0,
        "sessions" => %{},
        "total_work_units" => 1
      })
    end)

    client = client()

    assert {:ok, %{"total_work_units" => 1}} =
             Honchox.Workspaces.queue_status(client,
               observer_id: "obs-1",
               sender_id: "peer-1",
               session_id: "session-1"
             )
  end

  test "schedule_dream/2 posts the expected dream payload" do
    Req.Test.stub(HonchoxWorkspacesStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/schedule_dream"

      assert conn.body_params == %{
               "dream_type" => "omni",
               "observed" => "peer-2",
               "observer" => "peer-1",
               "session_id" => "session-9"
             }

      Plug.Conn.send_resp(conn, 204, "")
    end)

    client = client()

    assert {:ok, _body} =
             Honchox.Workspaces.schedule_dream(client,
               dream_type: "omni",
               observed: "peer-2",
               observer: "peer-1",
               session_id: "session-9"
             )
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      workspace_id: "workspace-1",
      base_url: "https://api.honcho.dev",
      plug: {Req.Test, HonchoxWorkspacesStub}
    )
  end
end
