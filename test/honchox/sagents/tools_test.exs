defmodule Honchox.Sagents.ToolsTest do
  use ExUnit.Case

  import Req.Test

  alias LangChain.Function

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "is a Sagents middleware that exposes Honchox conversation tools" do
    client = client()

    assert {:ok, config} = Honchox.Sagents.Tools.init(client: client)

    tools = Honchox.Sagents.Tools.tools(config)
    names = Enum.map(tools, & &1.name)

    assert "honchox_search_messages" in names
    assert "honchox_get_peer_context" in names
    assert "honchox_create_conclusions" in names
    assert "honchox_schedule_dream" in names
    assert "honchox_queue_status" in names
  end

  test "supports only and except tool selection options" do
    client = client()

    assert {:ok, only_config} =
             Honchox.Sagents.Tools.init(
               client: client,
               only: [:search_messages, "honchox_get_peer_context"]
             )

    assert only_config |> Honchox.Sagents.Tools.tools() |> Enum.map(& &1.name) == [
             "honchox_search_messages",
             "honchox_get_peer_context"
           ]

    assert {:ok, except_config} =
             Honchox.Sagents.Tools.init(
               client: client,
               except: [:schedule_dream, "honchox_queue_status"]
             )

    names = except_config |> Honchox.Sagents.Tools.tools() |> Enum.map(& &1.name)

    refute "honchox_schedule_dream" in names
    refute "honchox_queue_status" in names
    assert "honchox_search_messages" in names
    assert "honchox_get_peer_context" in names
    assert "honchox_create_conclusions" in names
  end

  test "rejects invalid tool selection options" do
    assert {:error, {:unknown_tools, [:missing_tool]}} =
             Honchox.Sagents.Tools.init(client: client(), only: [:missing_tool])

    assert {:error, :cannot_use_only_and_except_together} =
             Honchox.Sagents.Tools.init(client: client(), only: [:search_messages], except: [])
  end

  test "honchox_search_messages searches memory for an observer peer" do
    client = client()
    {:ok, config} = Honchox.Sagents.Tools.init(client: client)

    search_tool =
      Enum.find(Honchox.Sagents.Tools.tools(config), &(&1.name == "honchox_search_messages"))

    expect_workspace_ensure()

    Req.Test.expect(HonchoxSagentsToolsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/bot/search"

      assert conn.body_params == %{
               "query" => "favorite color",
               "limit" => 2
             }

      Req.Test.json(conn, [
        %{"id" => "msg-1", "peer_id" => "alice", "content" => "Alice likes blue."}
      ])
    end)

    assert {:ok, result} =
             Function.execute(
               search_tool,
               %{
                 "observer_id" => "bot",
                 "query" => "favorite color",
                 "limit" => 2
               },
               nil
             )

    assert Jason.decode!(result) == %{
             "messages" => [
               %{"id" => "msg-1", "peer_id" => "alice", "content" => "Alice likes blue."}
             ]
           }
  end

  defp expect_workspace_ensure(response_attrs \\ %{"id" => "workspace-1"}) do
    Req.Test.expect(HonchoxSagentsToolsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces"
      Req.Test.json(conn, response_attrs)
    end)
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxSagentsToolsStub},
      retry: false
    )
  end
end
