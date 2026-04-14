defmodule Honchox.ObservationsTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "list/2 delegates to the conclusions list endpoint" do
    Req.Test.stub(HonchoxObservationsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/list"
      assert URI.decode_query(conn.query_string) == %{"page" => "1", "size" => "50"}

      Req.Test.json(conn, %{"items" => [%{"id" => "o-1"}]})
    end)

    assert {:ok, %{"items" => [%{"id" => "o-1"}]}} =
             Honchox.Observations.list(client(), workspace_id: "workspace-1")
  end

  test "query/3 delegates to the conclusions query endpoint" do
    Req.Test.stub(HonchoxObservationsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/query"

      assert conn.body_params == %{
               "distance" => 0.5,
               "filters" => %{},
               "query" => "memory",
               "top_k" => 10
             }

      Req.Test.json(conn, [%{"id" => "o-1"}])
    end)

    assert {:ok, [%{"id" => "o-1"}]} =
             Honchox.Observations.query(client(), "memory", workspace_id: "workspace-1")
  end

  test "delete/2 delegates to the conclusions delete endpoint" do
    Req.Test.stub(HonchoxObservationsStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/conclusions/o-1"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, nil} = Honchox.Observations.delete(client(), "o-1", workspace_id: "workspace-1")
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      plug: {Req.Test, HonchoxObservationsStub}
    )
  end
end
