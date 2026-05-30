defmodule Honchox.KeysTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "create/2 posts workspace-scoped query params to the keys endpoint" do
    Req.Test.stub(HonchoxKeysStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/keys"
      assert URI.decode_query(conn.query_string) == %{"workspace_id" => "workspace-1"}

      Req.Test.json(conn, %{"key" => "jwt-1"})
    end)

    assert {:ok, %{"key" => "jwt-1"}} =
             Honchox.Keys.create(client(), workspace_id: "workspace-1")
  end

  test "create/2 posts all supported scope params" do
    Req.Test.stub(HonchoxKeysStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/keys"

      assert URI.decode_query(conn.query_string) == %{
               "peer_id" => "peer-1",
               "session_id" => "session-1",
               "workspace_id" => "workspace-1"
             }

      Req.Test.json(conn, %{"key" => "jwt-1"})
    end)

    assert {:ok, %{"key" => "jwt-1"}} =
             Honchox.Keys.create(client(),
               workspace_id: "workspace-1",
               peer_id: "peer-1",
               session_id: "session-1"
             )
  end

  test "create/2 converts expires_in into an expires_at query param" do
    Req.Test.stub(HonchoxKeysStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/keys"

      query = URI.decode_query(conn.query_string)
      assert %{"expires_at" => expires_at} = query
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(expires_at)

      Req.Test.json(conn, %{"key" => "jwt-1"})
    end)

    assert {:ok, %{"key" => "jwt-1"}} =
             Honchox.Keys.create(client(), expires_in: {1, :hour})
  end

  test "create/2 converts a DateTime expires_at into ISO 8601" do
    expires_at = DateTime.from_naive!(~N[2030-01-01 12:00:00], "Etc/UTC")

    Req.Test.stub(HonchoxKeysStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/keys"

      assert URI.decode_query(conn.query_string) == %{
               "expires_at" => "2030-01-01T12:00:00Z"
             }

      Req.Test.json(conn, %{"key" => "jwt-1"})
    end)

    assert {:ok, %{"key" => "jwt-1"}} =
             Honchox.Keys.create(client(), expires_at: expires_at)
  end

  test "create/2 returns an http error on non-2xx responses" do
    Req.Test.stub(HonchoxKeysStub, fn conn ->
      Plug.Conn.put_resp_content_type(conn, "application/json")
      Plug.Conn.send_resp(conn, 422, ~s({"detail":"invalid scope"}))
    end)

    assert {:error, %Honchox.Error{status: 422}} = Honchox.Keys.create(client(), [])
  end

  test "create_client/2 returns a scoped client authenticated with the JWT" do
    Req.Test.stub(HonchoxKeysStub, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer admin-secret"]
      Req.Test.json(conn, %{"key" => "jwt-scoped"})
    end)

    assert {:ok, %Honchox.Client{} = client} =
             Honchox.Keys.create_client(client(), workspace_id: "ws-1")

    assert client.jwt == "jwt-scoped"
    assert client.api_key == nil

    assert %{options: options} = client.req
    assert Map.get(options, :auth) == {:bearer, "jwt-scoped"}
  end

  test "create_client/2 inherits base_url, timeout, and max_retries from the admin client" do
    Req.Test.stub(HonchoxKeysStub, fn conn ->
      Req.Test.json(conn, %{"key" => "jwt-scoped"})
    end)

    admin_client =
      Honchox.new(
        api_key: "admin-secret",
        base_url: "https://api.honcho.dev",
        timeout: 15_000,
        max_retries: 4,
        plug: {Req.Test, HonchoxKeysStub}
      )

    assert {:ok, %Honchox.Client{} = scoped_client} =
             Honchox.Keys.create_client(admin_client, workspace_id: "ws-1")

    assert scoped_client.base_url == admin_client.base_url
    assert scoped_client.timeout == admin_client.timeout
    assert scoped_client.max_retries == admin_client.max_retries
  end

  defp client do
    Honchox.new(
      api_key: "admin-secret",
      base_url: "https://api.honcho.dev",
      plug: {Req.Test, HonchoxKeysStub}
    )
  end
end
