defmodule Honchox.HTTPTest do
  use ExUnit.Case
  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "get/3 sends bearer auth and query params" do
    Req.Test.stub(HonchoxHTTPStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.query_string == "page=1"
      Req.Test.json(conn, %{"ok" => true})
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxHTTPStub}
      )

    assert %Honchox.Client{} = client
    assert {:ok, %{"ok" => true}} = Honchox.HTTP.get(client, "/v3/workspaces", page: 1)
  end

  test "post/3 sends a JSON body" do
    Req.Test.stub(HonchoxHTTPStub, fn conn ->
      assert conn.method == "POST"
      assert conn.body_params == %{"name" => "Ada"}
      Req.Test.json(conn, %{"id" => "peer-1"})
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxHTTPStub}
      )

    assert {:ok, %{"id" => "peer-1"}} =
             Honchox.HTTP.post(client, "/v3/workspaces/ws/peers", %{name: "Ada"})
  end

  test "delete/3 returns ok nil for empty 204" do
    Req.Test.stub(HonchoxHTTPStub, fn conn ->
      Plug.Conn.send_resp(conn, 204, "")
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxHTTPStub}
      )

    assert {:ok, nil} = Honchox.HTTP.delete(client, "/v3/workspaces/ws/peers/peer-1")
  end

  test "maps non-2xx responses to Honchox.Error" do
    Req.Test.stub(HonchoxHTTPStub, fn conn ->
      Plug.Conn.put_resp_content_type(conn, "application/json")
      Plug.Conn.send_resp(conn, 422, ~s({"detail":"invalid"}))
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxHTTPStub},
        retry: false
      )

    assert {:error, %Honchox.Error{status: 422}} =
             Honchox.HTTP.get(client, "/v3/workspaces")
  end
end
