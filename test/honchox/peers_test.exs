defmodule Honchox.PeersTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "get_or_create/3 posts the peer id plus metadata and configuration" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers"

      assert %{
               "configuration" => %{"observe_me" => true},
               "id" => "alice",
               "metadata" => %{"role" => "user"}
             } = conn.body_params

      Req.Test.json(conn, %{"id" => "alice", "workspace_id" => "workspace-1"})
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.get_or_create(client, "alice",
        metadata: %{role: "user"},
        configuration: %{observe_me: true}
      )

    # Assert
    assert {:ok, %{"id" => "alice", "workspace_id" => "workspace-1"}} = result
  end

  test "update/3 patches the peer resource without an id in the body" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice"

      assert %{
               "configuration" => %{"observe_me" => false},
               "metadata" => %{"role" => "assistant"}
             } = conn.body_params

      refute Map.has_key?(conn.body_params, "id")

      Req.Test.json(conn, %{"id" => "alice", "workspace_id" => "workspace-1"})
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.update(client, "alice",
        metadata: %{role: "assistant"},
        configuration: %{observe_me: false}
      )

    # Assert
    assert {:ok, %{"id" => "alice", "workspace_id" => "workspace-1"}} = result
  end

  test "list/2 posts pagination and filters to the list endpoint" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/list"
      assert URI.decode_query(conn.query_string) == %{"page" => "2", "size" => "10"}
      assert conn.body_params == %{"filters" => %{"role" => "user"}}

      Req.Test.json(conn, %{
        "items" => [%{"id" => "alice"}],
        "page" => 2,
        "pages" => 1,
        "size" => 10,
        "total" => 1
      })
    end)

    client = client()

    # Act
    result = Honchox.Peers.list(client, page: 2, size: 10, filters: %{role: "user"})

    # Assert
    assert {:ok, %{"page" => 2, "items" => [%{"id" => "alice"}]}} = result
  end

  test "list_sessions/3 posts pagination and filters for a peer" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/sessions"
      assert URI.decode_query(conn.query_string) == %{"page" => "3", "size" => "25"}
      assert conn.body_params == %{"filters" => %{"is_active" => true}}

      Req.Test.json(conn, %{
        "items" => [%{"id" => "session-1"}],
        "page" => 3,
        "pages" => 1,
        "size" => 25,
        "total" => 1
      })
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.list_sessions(client, "alice",
        page: 3,
        size: 25,
        filters: %{is_active: true}
      )

    # Assert
    assert {:ok, %{"page" => 3, "items" => [%{"id" => "session-1"}]}} = result
  end

  test "chat/4 normalizes reasoning_level, target, and session_id into the request body" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/chat"

      assert %{
               "query" => "What should I do next?",
               "reasoning_level" => "high",
               "session_id" => "session-9",
               "target" => "bob"
             } = conn.body_params

      Req.Test.json(conn, %{"content" => "Focus on the launch checklist."})
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.chat(client, "alice", "What should I do next?",
        reasoning_level: "high",
        session_id: "session-9",
        target: "bob"
      )

    # Assert
    assert {:ok, %{"content" => "Focus on the launch checklist."}} = result
  end

  test "search/4 sends peer-scoped search parameters" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/search"

      assert %{
               "filters" => %{"session_id" => "session-9"},
               "limit" => 5,
               "query" => "launch checklist"
             } = conn.body_params

      Req.Test.json(conn, [
        %{"id" => "message-1", "session_id" => "session-9"},
        %{"id" => "message-2", "session_id" => "session-9"}
      ])
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.search(client, "alice", "launch checklist",
        filters: %{session_id: "session-9"},
        limit: 5
      )

    # Assert
    assert {:ok, [%{"id" => "message-1"}, %{"id" => "message-2"}]} = result
  end

  test "representation/3 curates the peer representation with semantic search options" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/representation"

      assert %{
               "include_most_frequent" => true,
               "max_conclusions" => 12,
               "search_max_distance" => 0.4,
               "search_query" => "preferences",
               "search_top_k" => 8,
               "session_id" => "session-9",
               "target" => "bob"
             } = conn.body_params

      Req.Test.json(conn, %{"representation" => "Likes concise planning."})
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.representation(client, "alice",
        include_most_frequent: true,
        max_conclusions: 12,
        search_max_distance: 0.4,
        search_query: "preferences",
        search_top_k: 8,
        session_id: "session-9",
        target: "bob"
      )

    # Assert
    assert {:ok, %{"representation" => "Likes concise planning."}} = result
  end

  test "context/3 returns the peer context with target support" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/context"

      assert URI.decode_query(conn.query_string) == %{
               "include_most_frequent" => "true",
               "max_conclusions" => "20",
               "search_query" => "preferences",
               "search_top_k" => "8",
               "target" => "bob"
             }

      Req.Test.json(conn, %{
        "peer_card" => ["Likes concise planning."],
        "peer_id" => "alice",
        "representation" => "Focuses on delivery.",
        "target_id" => "bob"
      })
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.context(client, "alice",
        include_most_frequent: true,
        max_conclusions: 20,
        search_query: "preferences",
        search_top_k: 8,
        target: "bob"
      )

    # Assert
    assert {:ok, context} = result
    assert context["peer_id"] == "alice"
    assert context["target_id"] == "bob"
    assert context["representation"] == "Focuses on delivery."
    assert context["peer_card"] == ["Likes concise planning."]
  end

  test "get_card/3 gets the peer card for a target peer" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/card"
      assert URI.decode_query(conn.query_string) == %{"target" => "bob"}

      Req.Test.json(conn, %{"peer_card" => ["Likes Python", "Works remotely"]})
    end)

    client = client()

    # Act
    result = Honchox.Peers.get_card(client, "alice", target: "bob")

    # Assert
    assert {:ok, %{"peer_card" => ["Likes Python", "Works remotely"]}} = result
  end

  test "set_card/4 writes the peer card for a target peer" do
    # Arrange
    Req.Test.stub(HonchoxPeersStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/card"
      assert URI.decode_query(conn.query_string) == %{"target" => "bob"}
      assert conn.body_params == %{"peer_card" => ["Works at Acme", "Enjoys hiking"]}

      Req.Test.json(conn, %{"peer_card" => ["Works at Acme", "Enjoys hiking"]})
    end)

    client = client()

    # Act
    result =
      Honchox.Peers.set_card(client, "alice", ["Works at Acme", "Enjoys hiking"], target: "bob")

    # Assert
    assert {:ok, %{"peer_card" => ["Works at Acme", "Enjoys hiking"]}} = result
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      workspace_id: "workspace-1",
      base_url: "https://api.honcho.dev",
      plug: {Req.Test, HonchoxPeersStub}
    )
  end
end
