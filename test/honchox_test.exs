defmodule HonchoxTest do
  use ExUnit.Case
  import Req.Test

  doctest Honchox

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "new/1 fails fast when required config is missing" do
    previous_env = env(["HONCHO_API_KEY", "HONCHO_WORKSPACE_ID", "HONCHO_URL"])

    on_exit(fn -> restore_env(previous_env) end)

    System.delete_env("HONCHO_API_KEY")
    System.delete_env("HONCHO_WORKSPACE_ID")
    System.delete_env("HONCHO_URL")

    assert_raise ArgumentError, "missing required Honchox config: api_key", fn ->
      Honchox.new()
    end
  end

  test "new/1 does not require workspace_id" do
    previous_env = env(["HONCHO_API_KEY", "HONCHO_WORKSPACE_ID", "HONCHO_URL"])

    on_exit(fn -> restore_env(previous_env) end)

    System.put_env("HONCHO_API_KEY", "env-secret")
    System.put_env("HONCHO_WORKSPACE_ID", "env-ws")
    System.put_env("HONCHO_URL", "https://api.env.example")

    client = Honchox.new()

    assert %Honchox{} = client
    assert client.api_key == "env-secret"
    assert client.workspace_id == nil
    assert client.base_url == "https://api.env.example"
  end

  test "new/1 uses explicit config over env vars" do
    previous_env = env(["HONCHO_API_KEY", "HONCHO_WORKSPACE_ID", "HONCHO_URL"])

    on_exit(fn -> restore_env(previous_env) end)

    System.put_env("HONCHO_API_KEY", "env-secret")
    System.put_env("HONCHO_WORKSPACE_ID", "env-ws")
    System.put_env("HONCHO_URL", "https://api.env.example")

    client =
      Honchox.new(
        api_key: "explicit-secret",
        workspace_id: "explicit-ws",
        base_url: "https://api.explicit.example"
      )

    assert %Honchox{} = client
    assert client.api_key == "explicit-secret"
    assert client.workspace_id == nil
    assert client.base_url == "https://api.explicit.example"
    assert client.req.options[:base_url] == "https://api.explicit.example"
    assert client.req.options[:auth] == {:bearer, "explicit-secret"}
  end

  test "new/1 does not read workspace_id from env vars" do
    previous_env = env(["HONCHO_API_KEY", "HONCHO_WORKSPACE_ID", "HONCHO_URL"])

    on_exit(fn -> restore_env(previous_env) end)

    System.put_env("HONCHO_API_KEY", "env-secret")
    System.put_env("HONCHO_WORKSPACE_ID", "env-ws")
    System.put_env("HONCHO_URL", "https://api.env.example")

    client = Honchox.new()

    assert client.workspace_id == nil
  end

  test "get/3 sends bearer auth and query params" do
    Req.Test.stub(HonchoxStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.query_string == "page=1"
      Req.Test.json(conn, %{"ok" => true})
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxStub}
      )

    assert {:ok, %{"ok" => true}} = Honchox.get(client, "/v3/workspaces", page: 1)
  end

  test "post/3 sends json body" do
    Req.Test.stub(HonchoxStub, fn conn ->
      assert conn.method == "POST"
      assert conn.body_params == %{"name" => "Ada"}
      Req.Test.json(conn, %{"id" => "peer-1"})
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxStub}
      )

    assert {:ok, %{"id" => "peer-1"}} =
             Honchox.post(client, "/v3/workspaces/ws/peers", %{name: "Ada"})
  end

  test "delete/3 returns ok nil for empty 204" do
    Req.Test.stub(HonchoxStub, fn conn ->
      Plug.Conn.send_resp(conn, 204, "")
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxStub}
      )

    assert {:ok, nil} = Honchox.delete(client, "/v3/workspaces/ws/peers/peer-1")
  end

  test "retries on 500 and succeeds on second attempt" do
    Req.Test.expect(HonchoxStub, fn conn ->
      assert conn.method == "POST"
      Plug.Conn.send_resp(conn, 500, "server error")
    end)

    Req.Test.expect(HonchoxStub, fn conn ->
      assert conn.method == "POST"
      Req.Test.json(conn, %{"id" => "peer-1"})
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxStub}
      )

    assert {:ok, %{"id" => "peer-1"}} =
             Honchox.post(client, "/v3/workspaces/ws/peers", %{name: "Ada"})
  end

  test "maps transport failures to transport errors" do
    Req.Test.stub(HonchoxStub, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxStub},
        retry: false
      )

    assert {:error,
            %Honchox.Error{
              kind: :transport,
              code: :econnrefused,
              message: message
            }} = Honchox.get(client, "/v3/workspaces")

    assert message =~ "connection refused"
  end

  test "maps timeout failures to timeout errors" do
    Req.Test.stub(HonchoxStub, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    client =
      Honchox.new(
        api_key: "secret",
        base_url: "https://api.honcho.dev",
        plug: {Req.Test, HonchoxStub},
        retry: false
      )

    assert {:error,
            %Honchox.Error{
              kind: :timeout,
              code: :timeout,
              message: message
            }} = Honchox.get(client, "/v3/workspaces")

    assert message =~ "timeout"
  end

  defp env(keys) do
    Enum.into(keys, %{}, fn key -> {key, System.get_env(key)} end)
  end

  defp restore_env(previous_env) do
    Enum.each(previous_env, fn
      {key, nil} -> System.delete_env(key)
      {key, value} -> System.put_env(key, value)
    end)
  end
end
