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

  test "new/1 uses environment workspace fallback" do
    previous_env = env(["HONCHO_API_KEY", "HONCHO_WORKSPACE_ID", "HONCHO_URL"])

    on_exit(fn -> restore_env(previous_env) end)

    System.put_env("HONCHO_API_KEY", "env-secret")
    System.put_env("HONCHO_WORKSPACE_ID", "env-ws")
    System.put_env("HONCHO_URL", "https://api.env.example")

    client = Honchox.new()

    assert %Honchox.Client{} = client
    assert client.api_key == "env-secret"
    assert client.workspace_id == "env-ws"
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

    assert %Honchox.Client{} = client
    assert client.api_key == "explicit-secret"
    assert client.workspace_id == "explicit-ws"
    assert client.base_url == "https://api.explicit.example"
    assert client.req.options[:base_url] == "https://api.explicit.example"
    assert client.req.options[:auth] == {:bearer, "explicit-secret"}
  end

  test "new/1 defaults workspace_id when absent" do
    previous_env = env(["HONCHO_API_KEY", "HONCHO_WORKSPACE_ID", "HONCHO_URL"])

    on_exit(fn -> restore_env(previous_env) end)

    System.put_env("HONCHO_API_KEY", "env-secret")
    System.delete_env("HONCHO_WORKSPACE_ID")
    System.delete_env("HONCHO_URL")

    client = Honchox.new()

    assert client.workspace_id == "default"
    assert client.base_url == "https://api.honcho.dev"
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
