defmodule Honchox.SessionsTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "get_or_create/3 posts the session id plus metadata and configuration" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions"

      assert %{
               "configuration" => %{"type" => "meeting"},
               "id" => "session-1",
               "metadata" => %{"topic" => "launch"}
             } = conn.body_params

      Req.Test.json(conn, %{"id" => "session-1"})
    end)

    assert {:ok, %{"id" => "session-1"}} =
             Honchox.Sessions.get_or_create(client(), "session-1",
               workspace_id: "workspace-1",
               metadata: %{topic: "launch"},
               configuration: %{type: "meeting"}
             )
  end

  test "update/3 puts metadata and configuration without id" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1"

      assert conn.body_params == %{
               "configuration" => %{"mode" => "focus"},
               "metadata" => %{"topic" => "review"}
             }

      refute Map.has_key?(conn.body_params, "id")

      Req.Test.json(conn, %{"id" => "session-1"})
    end)

    assert {:ok, %{"id" => "session-1"}} =
             Honchox.Sessions.update(client(), "session-1",
               workspace_id: "workspace-1",
               metadata: %{topic: "review"},
               configuration: %{mode: "focus"}
             )
  end

  test "delete/2 deletes the session by id" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1"
      Plug.Conn.send_resp(conn, 202, "")
    end)

    assert {:ok, ""} = Honchox.Sessions.delete(client(), "session-1", workspace_id: "workspace-1")
  end

  test "clone/3 posts clone options to the clone endpoint" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/clone"
      assert conn.body_params == %{"message_id" => "msg-9"}

      Req.Test.json(conn, %{"id" => "session-2"})
    end)

    assert {:ok, %{"id" => "session-2"}} =
             Honchox.Sessions.clone(client(), "session-1",
               workspace_id: "workspace-1",
               message_id: "msg-9"
             )
  end

  test "context/3 encodes session context options as query params" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/context"

      assert URI.decode_query(conn.query_string) == %{
               "include_most_frequent" => "true",
               "limit_to_session" => "true",
               "max_conclusions" => "25",
               "peer_perspective" => "assistant",
               "peer_target" => "user",
               "search_max_distance" => "0.8",
               "search_query" => "preferences",
               "search_top_k" => "10",
               "summary" => "true",
               "tokens" => "2000"
             }

      Req.Test.json(conn, %{"id" => "session-1", "messages" => []})
    end)

    assert {:ok, %{"id" => "session-1"}} =
             Honchox.Sessions.context(client(), "session-1",
               workspace_id: "workspace-1",
               summary: true,
               tokens: 2000,
               peer_target: "user",
               peer_perspective: "assistant",
               search_query: "preferences",
               limit_to_session: true,
               search_top_k: 10,
               search_max_distance: 0.8,
               include_most_frequent: true,
               max_conclusions: 25
             )
  end

  test "summaries/2 gets available summaries for a session" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/summaries"

      Req.Test.json(conn, %{"id" => "session-1", "short_summary" => %{"content" => "..."}})
    end)

    assert {:ok, %{"id" => "session-1"}} =
             Honchox.Sessions.summaries(client(), "session-1", workspace_id: "workspace-1")
  end

  test "search/4 posts a query with filters and limit" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/search"

      assert conn.body_params == %{
               "filters" => %{"peer_id" => "alice"},
               "limit" => 5,
               "query" => "launch"
             }

      Req.Test.json(conn, %{"items" => [%{"id" => "msg-1"}]})
    end)

    assert {:ok, %{"items" => [%{"id" => "msg-1"}]}} =
             Honchox.Sessions.search(client(), "session-1", "launch",
               workspace_id: "workspace-1",
               filters: %{peer_id: "alice"},
               limit: 5
             )
  end

  test "add_peers/3 posts peers to the session peer collection" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"

      assert conn.body_params == %{
               "peers" => [%{"peer_id" => "alice"}, %{"peer_id" => "assistant"}]
             }

      Req.Test.json(conn, %{"items" => [%{"peer_id" => "alice"}, %{"peer_id" => "assistant"}]})
    end)

    peers = [%{peer_id: "alice"}, %{peer_id: "assistant"}]

    assert {:ok, %{"items" => [_ | _]}} =
             Honchox.Sessions.add_peers(client(), "session-1", peers, workspace_id: "workspace-1")
  end

  test "set_peers/3 replaces session peers" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
      assert conn.body_params == %{"peers" => [%{"peer_id" => "alice"}]}

      Req.Test.json(conn, %{"items" => [%{"peer_id" => "alice"}]})
    end)

    assert {:ok, %{"items" => [%{"peer_id" => "alice"}]}} =
             Honchox.Sessions.set_peers(client(), "session-1", [%{peer_id: "alice"}],
               workspace_id: "workspace-1"
             )
  end

  test "remove_peers/3 deletes peers from the session" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
      assert URI.decode_query(conn.query_string) == %{"peer_ids" => "alice,assistant"}

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, nil} =
             Honchox.Sessions.remove_peers(client(), "session-1", ["alice", "assistant"],
               workspace_id: "workspace-1"
             )
  end

  test "list_peers/2 gets peers for a session" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"

      Req.Test.json(conn, %{"items" => [%{"peer_id" => "alice"}]})
    end)

    assert {:ok, %{"items" => [%{"peer_id" => "alice"}]}} =
             Honchox.Sessions.list_peers(client(), "session-1", workspace_id: "workspace-1")
  end

  test "get_peer_config/3 gets session-level peer configuration" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "GET"

      assert conn.request_path ==
               "/v3/workspaces/workspace-1/sessions/session-1/peers/alice/config"

      Req.Test.json(conn, %{"observe_me" => true, "observe_others" => false})
    end)

    assert {:ok, %{"observe_me" => true}} =
             Honchox.Sessions.get_peer_config(client(), "session-1", "alice",
               workspace_id: "workspace-1"
             )
  end

  test "set_peer_config/4 updates session-level peer configuration" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "PUT"

      assert conn.request_path ==
               "/v3/workspaces/workspace-1/sessions/session-1/peers/alice/config"

      assert conn.body_params == %{"observe_me" => false, "observe_others" => true}

      Req.Test.json(conn, %{"observe_me" => false, "observe_others" => true})
    end)

    assert {:ok, %{"observe_me" => false}} =
             Honchox.Sessions.set_peer_config(
               client(),
               "session-1",
               "alice",
               %{observe_me: false, observe_others: true},
               workspace_id: "workspace-1"
             )
  end

  test "add_messages/3 posts a batch of messages" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages"

      assert conn.body_params == %{
               "messages" => [
                 %{"content" => "hello", "peer_id" => "alice"},
                 %{"content" => "hi", "peer_id" => "assistant"}
               ]
             }

      Req.Test.json(conn, [%{"id" => "msg-1"}, %{"id" => "msg-2"}])
    end)

    messages = [%{peer_id: "alice", content: "hello"}, %{peer_id: "assistant", content: "hi"}]

    assert {:ok, [%{"id" => "msg-1"}, %{"id" => "msg-2"}]} =
             Honchox.Sessions.add_messages(client(), "session-1", messages,
               workspace_id: "workspace-1"
             )
  end

  test "list_messages/3 posts list filters with pagination" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "reverse" => "true",
               "size" => "25"
             }

      assert conn.body_params == %{"filters" => %{"peer_id" => "alice"}}

      Req.Test.json(conn, %{"items" => [%{"id" => "msg-1"}], "page" => 2})
    end)

    assert {:ok, %{"page" => 2}} =
             Honchox.Sessions.list_messages(client(), "session-1",
               workspace_id: "workspace-1",
               page: 2,
               size: 25,
               reverse: true,
               filters: %{peer_id: "alice"}
             )
  end

  test "get_message/3 gets a message by id" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/msg-1"

      Req.Test.json(conn, %{"id" => "msg-1", "content" => "hello"})
    end)

    assert {:ok, %{"id" => "msg-1"}} =
             Honchox.Sessions.get_message(client(), "session-1", "msg-1",
               workspace_id: "workspace-1"
             )
  end

  test "update_message/4 updates a message payload" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/msg-1"
      assert conn.body_params == %{"content" => "updated", "metadata" => %{"source" => "edit"}}

      Req.Test.json(conn, %{"id" => "msg-1", "content" => "updated"})
    end)

    assert {:ok, %{"content" => "updated"}} =
             Honchox.Sessions.update_message(
               client(),
               "session-1",
               "msg-1",
               %{content: "updated", metadata: %{source: "edit"}},
               workspace_id: "workspace-1"
             )
  end

  test "upload_file/4 sends multipart form data" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/files"

      assert Enum.any?(
               Plug.Conn.get_req_header(conn, "content-type"),
               &String.starts_with?(&1, "multipart/form-data;")
             )

      Req.Test.json(conn, [%{"id" => "msg-upload-1"}])
    end)

    assert {:ok, [%{"id" => "msg-upload-1"}]} =
             Honchox.Sessions.upload_file(client(), "session-1", {"notes.txt", "hello world"},
               workspace_id: "workspace-1",
               peer: "alice",
               metadata: %{source: "upload"},
               created_at: "2024-01-15T10:30:00Z"
             )
  end

  test "queue_status/3 gets queue status scoped to the session" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/queue/status"

      assert URI.decode_query(conn.query_string) == %{
               "observer_id" => "assistant",
               "sender_id" => "alice"
             }

      Req.Test.json(conn, %{"total_work_units" => 2})
    end)

    assert {:ok, %{"total_work_units" => 2}} =
             Honchox.Sessions.queue_status(client(), "session-1",
               workspace_id: "workspace-1",
               observer_id: "assistant",
               sender_id: "alice"
             )
  end

  test "representation/4 posts peer representation options for the session" do
    Req.Test.stub(HonchoxSessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/representation"

      assert conn.body_params == %{
               "include_most_frequent" => true,
               "max_conclusions" => 10,
               "peer_id" => "alice",
               "search_query" => "preferences",
               "search_top_k" => 5,
               "target" => "assistant"
             }

      Req.Test.json(conn, %{"representation" => "Prefers concise answers."})
    end)

    assert {:ok, %{"representation" => "Prefers concise answers."}} =
             Honchox.Sessions.representation(client(), "session-1", "alice",
               workspace_id: "workspace-1",
               target: "assistant",
               search_query: "preferences",
               search_top_k: 5,
               include_most_frequent: true,
               max_conclusions: 10
             )
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      plug: {Req.Test, HonchoxSessionsStub}
    )
  end
end
