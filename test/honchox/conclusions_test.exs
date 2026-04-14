defmodule Honchox.ConclusionsTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "list/2 posts filters with pagination to the conclusions list endpoint" do
    Req.Test.stub(HonchoxConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/list"
      assert URI.decode_query(conn.query_string) == %{"page" => "2", "size" => "10"}
      assert conn.body_params == %{"filters" => %{"observed_id" => "alice"}}

      Req.Test.json(conn, %{"items" => [%{"id" => "c-1"}], "page" => 2})
    end)

    assert {:ok, %{"page" => 2}} =
             Honchox.Conclusions.list(client(),
               page: 2,
               size: 10,
               filters: %{observed_id: "alice"}
             )
  end

  test "query/3 posts a semantic query for conclusions" do
    Req.Test.stub(HonchoxConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/query"

      assert conn.body_params == %{
               "distance" => 0.4,
               "filters" => %{"observed_id" => "alice"},
               "query" => "preferences",
               "top_k" => 5
             }

      Req.Test.json(conn, [%{"id" => "c-1"}])
    end)

    assert {:ok, [%{"id" => "c-1"}]} =
             Honchox.Conclusions.query(client(), "preferences",
               top_k: 5,
               distance: 0.4,
               filters: %{observed_id: "alice"}
             )
  end

  test "create/2 posts one or more conclusions" do
    Req.Test.stub(HonchoxConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions"

      assert conn.body_params == %{
               "conclusions" => [
                 %{
                   "content" => "Prefers concise answers",
                   "observed_id" => "alice",
                   "observer_id" => "assistant",
                   "session_id" => "session-1"
                 }
               ]
             }

      Req.Test.json(conn, [%{"id" => "c-1"}])
    end)

    conclusions = [
      %{
        content: "Prefers concise answers",
        observer_id: "assistant",
        observed_id: "alice",
        session_id: "session-1"
      }
    ]

    assert {:ok, [%{"id" => "c-1"}]} = Honchox.Conclusions.create(client(), conclusions)
  end

  test "delete/2 deletes a conclusion by id" do
    Req.Test.stub(HonchoxConclusionsStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/c-1"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, nil} = Honchox.Conclusions.delete(client(), "c-1")
  end

  test "representation/2 posts representation helper options" do
    Req.Test.stub(HonchoxConclusionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/representation"

      assert conn.body_params == %{
               "observed_id" => "alice",
               "observer_id" => "assistant",
               "session_id" => "session-1"
             }

      Req.Test.json(conn, %{"representation" => "Concise and direct."})
    end)

    assert {:ok, %{"representation" => "Concise and direct."}} =
             Honchox.Conclusions.representation(client(),
               observer_id: "assistant",
               observed_id: "alice",
               session_id: "session-1"
             )
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      workspace_id: "workspace-1",
      base_url: "https://api.honcho.dev",
      plug: {Req.Test, HonchoxConclusionsStub}
    )
  end
end
