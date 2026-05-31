defmodule Honchox.PeerTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "message/3 builds a MessageInput without performing HTTP" do
    peer = peer()

    assert %{
             __struct__: Honchox.MessageInput,
             peer_id: "alice",
             content: "hello",
             metadata: %{source: "test"},
             configuration: %{reasoning: %{custom_instructions: "brief"}},
             created_at: "2026-05-31T00:00:00Z"
           } =
             Honchox.Peer.message(peer, "hello",
               metadata: %{source: "test"},
               configuration: %{reasoning: %{custom_instructions: "brief"}},
               created_at: "2026-05-31T00:00:00Z"
             )
  end

  test "chat/3 ensures workspace, posts SDK non-stream body, and returns content" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/chat"

      assert conn.body_params == %{
               "query" => "hello",
               "stream" => false,
               "target" => "bot",
               "session_id" => "session-1",
               "reasoning_level" => "high"
             }

      Req.Test.json(conn, %{"content" => "hi"})
    end)

    assert {:ok, "hi"} =
             Honchox.Peer.chat(peer(), "hello",
               target: %Honchox.Peer{id: "bot"},
               session: %Honchox.Session{id: "session-1"},
               reasoning_level: "high"
             )
  end

  test "chat/3 maps empty or absent content to nil" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/chat"
      Req.Test.json(conn, %{"content" => ""})
    end)

    assert {:ok, nil} = Honchox.Peer.chat(peer(), "hello")
  end

  test "search/3 posts SDK body and returns message structs" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/search"

      assert conn.body_params == %{
               "query" => "prefs",
               "filters" => %{"kind" => "message"},
               "limit" => 4
             }

      Req.Test.json(conn, [
        %{
          "id" => "msg-1",
          "content" => "tea",
          "peer_id" => "alice",
          "workspace_id" => "workspace-1"
        }
      ])
    end)

    assert {:ok, [%Honchox.Message{id: "msg-1", content: "tea", peer_id: "alice"}]} =
             Honchox.Peer.search(peer(), "prefs",
               filters: %{kind: "message"},
               limit: 4
             )
  end

  test "representation/2 normalizes options and returns representation string" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/representation"

      assert conn.body_params == %{
               "target" => "bot",
               "session_id" => "session-1",
               "search_query" => "prefs",
               "search_top_k" => 5,
               "search_max_distance" => 0.7,
               "include_most_frequent" => true,
               "max_conclusions" => 12
             }

      Req.Test.json(conn, %{"representation" => "Prefers tea."})
    end)

    assert {:ok, "Prefers tea."} =
             Honchox.Peer.representation(peer(),
               target: %Honchox.Peer{id: "bot"},
               session: %Honchox.Session{id: "session-1"},
               search_query: %Honchox.Message{content: "prefs"},
               search_top_k: 5,
               search_max_distance: 0.7,
               include_most_frequent: true,
               max_conclusions: 12
             )
  end

  test "context/2 normalizes query options and returns a PeerContext struct" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/context"

      assert URI.decode_query(conn.query_string) == %{
               "target" => "bot",
               "search_query" => "prefs",
               "search_top_k" => "5",
               "search_max_distance" => "0.7",
               "include_most_frequent" => "true",
               "max_conclusions" => "12"
             }

      Req.Test.json(conn, %{
        "peer_id" => "alice",
        "target_id" => "bot",
        "representation" => "Prefers tea.",
        "peer_card" => ["concise"]
      })
    end)

    assert {:ok,
            %Honchox.PeerContext{
              peer_id: "alice",
              target_id: "bot",
              representation: "Prefers tea.",
              peer_card: ["concise"]
            }} =
             Honchox.Peer.context(peer(),
               target: %Honchox.Peer{id: "bot"},
               session: %Honchox.Session{id: "session-1"},
               search_query: %Honchox.Message{content: "prefs"},
               search_top_k: 5,
               search_max_distance: 0.7,
               include_most_frequent: true,
               max_conclusions: 12
             )
  end

  test "get_card/2 and set_card/3 normalize target and return only peer_card" do
    expect_workspace_ensure()

    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/card"
      assert URI.decode_query(conn.query_string) == %{"target" => "bot"}

      Req.Test.json(conn, %{"peer_card" => ["concise"]})
    end)

    assert {:ok, ["concise"]} =
             Honchox.Peer.get_card(peer(), target: %Honchox.Peer{id: "bot"})

    expect_workspace_ensure()

    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/card"
      assert URI.decode_query(conn.query_string) == %{"target" => "bot"}
      assert conn.body_params == %{"peer_card" => ["concise", "technical"]}

      Req.Test.json(conn, %{"peer_card" => ["concise", "technical"]})
    end)

    assert {:ok, ["concise", "technical"]} =
             Honchox.Peer.set_card(peer(), ["concise", "technical"], target: "bot")
  end

  defp expect_workspace_ensure(response_attrs \\ %{"id" => "workspace-1"}) do
    Req.Test.expect(HonchoxPeerStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces"
      assert conn.body_params == Map.take(response_attrs, ["id", "metadata", "configuration"])

      Req.Test.json(conn, response_attrs)
    end)
  end

  defp peer do
    %Honchox.Peer{id: "alice", workspace_id: "workspace-1", client: client()}
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxPeerStub},
      retry: false
    )
  end
end
