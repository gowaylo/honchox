defmodule Honchox.ClientTest do
  use ExUnit.Case

  @env_keys ["HONCHO_API_KEY", "HONCHO_WORKSPACE_ID", "HONCHO_URL"]

  setup do
    previous_env = env(@env_keys)
    on_exit(fn -> restore_env(previous_env) end)
    :ok
  end

  test "new/1 returns Honchox.Client with SDK defaults" do
    clear_env(@env_keys)

    client = Honchox.new(api_key: "sk")

    assert %Honchox.Client{} = client
    assert client.api_key == "sk"
    assert client.workspace_id == "default"
    assert client.base_url == "https://api.honcho.dev"
    assert %Req.Request{} = client.req
    assert client.req.options[:base_url] == "https://api.honcho.dev"
    assert client.req.options[:auth] == {:bearer, "sk"}
    assert client.req.options[:receive_timeout] == 60_000
    assert client.req.options[:retry] == :transient
    assert client.req.options[:max_retries] == 2
  end

  test "new/1 uses HONCHO_URL and HONCHO_WORKSPACE_ID when options are absent" do
    clear_env(@env_keys)

    System.put_env("HONCHO_API_KEY", "env-secret")
    System.put_env("HONCHO_URL", "https://api.env.example")
    System.put_env("HONCHO_WORKSPACE_ID", "env-ws")

    client = Honchox.new()

    assert %Honchox.Client{} = client
    assert client.api_key == "env-secret"
    assert client.workspace_id == "env-ws"
    assert client.base_url == "https://api.env.example"
    assert client.req.options[:base_url] == "https://api.env.example"
    assert client.req.options[:auth] == {:bearer, "env-secret"}
  end

  test "new/1 explicit config wins over env vars" do
    clear_env(@env_keys)

    System.put_env("HONCHO_API_KEY", "env-secret")
    System.put_env("HONCHO_URL", "https://api.env.example")
    System.put_env("HONCHO_WORKSPACE_ID", "env-ws")

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

  test "new/1 stores explicit workspace_id on the client" do
    clear_env(@env_keys)

    client = Honchox.new(api_key: "sk", workspace_id: "ws")

    assert %Honchox.Client{} = client
    assert client.workspace_id == "ws"
  end

  test "new/1 accepts explicit timeout and retry options" do
    clear_env(@env_keys)

    client = Honchox.new(api_key: "sk", timeout: 30_000, max_retries: 4)

    assert client.timeout == 30_000
    assert client.max_retries == 4
    assert client.req.options[:receive_timeout] == 30_000
    assert client.req.options[:max_retries] == 4
  end

  defp env(keys) do
    Enum.into(keys, %{}, fn key -> {key, System.get_env(key)} end)
  end

  defp clear_env(keys) do
    Enum.each(keys, &System.delete_env/1)
  end

  defp restore_env(previous_env) do
    Enum.each(previous_env, fn
      {key, nil} -> System.delete_env(key)
      {key, value} -> System.put_env(key, value)
    end)
  end
end
