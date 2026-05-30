defmodule Honchox.API.SessionsTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  test "list/2 posts workspace session filters with SDK pagination query" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "size" => "25"
             }

      assert conn.body_params == %{"filters" => %{"metadata.topic" => "support"}}

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} =
             Honchox.API.Sessions.list(client(),
               page: 2,
               size: 25,
               reverse: false,
               filters: %{"metadata.topic" => "support"}
             )
  end

  test "clone/3 sends message_id as a query parameter and no JSON body" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/clone"
      assert URI.decode_query(conn.query_string) == %{"message_id" => "msg-9"}
      assert conn.body_params == %{}

      Req.Test.json(conn, %{"id" => "session-2"})
    end)

    assert {:ok, %{"id" => "session-2"}} =
             Honchox.API.Sessions.clone(client(), "session-1", message_id: "msg-9")
  end

  test "add_peers/3 sends the peer payload directly" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
      assert conn.query_string == ""

      assert conn.body_params == %{
               "_json" => [%{"peer_id" => "alice"}, %{"peer_id" => "assistant"}]
             }

      Req.Test.json(conn, %{"items" => [%{"peer_id" => "alice"}, %{"peer_id" => "assistant"}]})
    end)

    peers = [%{peer_id: "alice"}, %{peer_id: "assistant"}]

    assert {:ok, %{"items" => [_ | _]}} =
             Honchox.API.Sessions.add_peers(client(), "session-1", peers)
  end

  test "set_peers/3 sends the peer payload directly" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
      assert conn.query_string == ""
      assert conn.body_params == %{"_json" => [%{"peer_id" => "alice"}]}

      Req.Test.json(conn, %{"items" => [%{"peer_id" => "alice"}]})
    end)

    assert {:ok, %{"items" => [%{"peer_id" => "alice"}]}} =
             Honchox.API.Sessions.set_peers(client(), "session-1", [%{peer_id: "alice"}])
  end

  test "remove_peers/3 sends a DELETE JSON body without peer_ids query" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
      assert conn.query_string == ""
      assert conn.body_params == %{"_json" => ["alice", "assistant"]}

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, nil} =
             Honchox.API.Sessions.remove_peers(client(), "session-1", ["alice", "assistant"])
  end

  test "upload_file/4 posts SDK multipart fields to messages/upload" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/upload"

      assert Enum.any?(
               Plug.Conn.get_req_header(conn, "content-type"),
               &String.starts_with?(&1, "multipart/form-data;")
             )

      assert %{
               "peer_id" => "alice",
               "metadata" => ~s({"source":"upload"}),
               "configuration" => ~s({"summarize":false}),
               "created_at" => "2024-01-15T10:30:00Z"
             } = conn.body_params

      Req.Test.json(conn, [%{"id" => "msg-upload-1"}])
    end)

    assert {:ok, [%{"id" => "msg-upload-1"}]} =
             Honchox.API.Sessions.upload_file(client(), "session-1", {"notes.txt", "hello world"},
               peer_id: "alice",
               metadata: %{source: "upload"},
               configuration: %{summarize: false},
               created_at: "2024-01-15T10:30:00Z"
             )
  end

  test "queue_status/3 uses the workspace queue endpoint with session_id query" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/queue/status"

      assert URI.decode_query(conn.query_string) == %{
               "observer_id" => "assistant",
               "sender_id" => "alice",
               "session_id" => "session-1"
             }

      Req.Test.json(conn, %{"total_work_units" => 2})
    end)

    assert {:ok, %{"total_work_units" => 2}} =
             Honchox.API.Sessions.queue_status(client(), "session-1",
               observer_id: "assistant",
               sender_id: "alice"
             )
  end

  test "representation/4 delegates to peer representation with session_id in the body" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/representation"

      assert conn.body_params == %{
               "include_most_frequent" => true,
               "max_conclusions" => 10,
               "search_query" => "preferences",
               "search_top_k" => 5,
               "session_id" => "session-1",
               "target" => "assistant"
             }

      Req.Test.json(conn, %{"representation" => "Prefers concise answers."})
    end)

    assert {:ok, %{"representation" => "Prefers concise answers."}} =
             Honchox.API.Sessions.representation(client(), "session-1", "alice",
               target: "assistant",
               search_query: "preferences",
               search_top_k: 5,
               include_most_frequent: true,
               max_conclusions: 10
             )
  end

  test "get_or_create/3 posts session id and attrs" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions"

      assert conn.body_params == %{
               "id" => "session-1",
               "metadata" => %{"topic" => "support"},
               "peers" => [%{"id" => "alice"}]
             }

      Req.Test.json(conn, %{"id" => "session-1"})
    end)

    assert {:ok, %{"id" => "session-1"}} =
             Honchox.API.Sessions.get_or_create(client(), "session-1",
               metadata: %{topic: "support"},
               peers: [%{id: "alice"}]
             )
  end

  test "update/3 puts session attrs" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1"
      assert conn.body_params == %{"configuration" => %{"public" => false}}

      Req.Test.json(conn, %{"id" => "session-1"})
    end)

    assert {:ok, %{"id" => "session-1"}} =
             Honchox.API.Sessions.update(client(), "session-1", configuration: %{public: false})
  end

  test "delete/2 deletes session" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1"
      assert conn.query_string == ""

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, nil} = Honchox.API.Sessions.delete(client(), "session-1")
  end

  test "context/3 sends SDK context query options" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/context"

      assert URI.decode_query(conn.query_string) == %{
               "include_most_frequent" => "true",
               "limit_to_session" => "true",
               "max_conclusions" => "6",
               "peer_perspective" => "bot",
               "peer_target" => "alice",
               "search_max_distance" => "0.55",
               "search_query" => "billing",
               "search_top_k" => "4",
               "summary" => "true",
               "tokens" => "800"
             }

      Req.Test.json(conn, %{"context" => []})
    end)

    assert {:ok, %{"context" => []}} =
             Honchox.API.Sessions.context(client(), "session-1",
               tokens: 800,
               summary: true,
               search_query: "billing",
               peer_target: "alice",
               peer_perspective: "bot",
               limit_to_session: true,
               search_top_k: 4,
               search_max_distance: 0.55,
               include_most_frequent: true,
               max_conclusions: 6
             )
  end

  test "summaries/2 gets session summaries" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/summaries"
      assert conn.query_string == ""

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} = Honchox.API.Sessions.summaries(client(), "session-1")
  end

  test "search/4 posts SDK search body" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/search"

      assert conn.body_params == %{
               "query" => "refund",
               "filters" => %{"kind" => "message"},
               "limit" => 3
             }

      Req.Test.json(conn, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} =
             Honchox.API.Sessions.search(client(), "session-1", "refund",
               filters: %{kind: "message"},
               limit: 3
             )
  end

  test "list_peers/2 gets session peers" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
      assert conn.query_string == ""

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} = Honchox.API.Sessions.list_peers(client(), "session-1")
  end

  test "get_peer_config/3 gets session peer config" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "GET"

      assert conn.request_path ==
               "/v3/workspaces/workspace-1/sessions/session-1/peers/alice/config"

      assert conn.query_string == ""

      Req.Test.json(conn, %{"observe_me" => true})
    end)

    assert {:ok, %{"observe_me" => true}} =
             Honchox.API.Sessions.get_peer_config(client(), "session-1", "alice")
  end

  test "set_peer_config/4 puts session peer config" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "PUT"

      assert conn.request_path ==
               "/v3/workspaces/workspace-1/sessions/session-1/peers/alice/config"

      assert conn.body_params == %{"observe_me" => true, "observe_others" => false}

      Req.Test.json(conn, %{"observe_me" => true, "observe_others" => false})
    end)

    assert {:ok, %{"observe_me" => true, "observe_others" => false}} =
             Honchox.API.Sessions.set_peer_config(client(), "session-1", "alice",
               observe_me: true,
               observe_others: false
             )
  end

  test "add_messages/3 wraps messages in SDK messages body" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages"

      assert conn.body_params == %{
               "messages" => [
                 %{
                   "peer_id" => "alice",
                   "content" => "hello",
                   "metadata" => %{"source" => "test"},
                   "configuration" => %{"visible" => true},
                   "created_at" => "2024-01-15T10:30:00Z"
                 }
               ]
             }

      Req.Test.json(conn, [%{"id" => "message-1"}])
    end)

    messages = [
      %{
        peer_id: "alice",
        content: "hello",
        metadata: %{source: "test"},
        configuration: %{visible: true},
        created_at: "2024-01-15T10:30:00Z"
      }
    ]

    assert {:ok, [%{"id" => "message-1"}]} =
             Honchox.API.Sessions.add_messages(client(), "session-1", messages)
  end

  test "list_messages/3 posts filters with SDK pagination query" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/list"

      assert URI.decode_query(conn.query_string) == %{
               "page" => "2",
               "reverse" => "true",
               "size" => "20"
             }

      assert conn.body_params == %{"filters" => %{"peer_id" => "alice"}}

      Req.Test.json(conn, %{"items" => []})
    end)

    assert {:ok, %{"items" => []}} =
             Honchox.API.Sessions.list_messages(client(), "session-1",
               page: 2,
               size: 20,
               reverse: true,
               filters: %{peer_id: "alice"}
             )
  end

  test "get_message/3 gets a message by id" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "GET"

      assert conn.request_path ==
               "/v3/workspaces/workspace-1/sessions/session-1/messages/message-1"

      assert conn.query_string == ""

      Req.Test.json(conn, %{"id" => "message-1"})
    end)

    assert {:ok, %{"id" => "message-1"}} =
             Honchox.API.Sessions.get_message(client(), "session-1", "message-1")
  end

  test "update_message/4 puts SDK metadata body" do
    Req.Test.stub(HonchoxAPISessionsStub, fn conn ->
      assert conn.method == "PUT"

      assert conn.request_path ==
               "/v3/workspaces/workspace-1/sessions/session-1/messages/message-1"

      assert conn.body_params == %{"metadata" => %{"reviewed" => true}}

      Req.Test.json(conn, %{"id" => "message-1"})
    end)

    assert {:ok, %{"id" => "message-1"}} =
             Honchox.API.Sessions.update_message(client(), "session-1", "message-1",
               metadata: %{reviewed: true}
             )
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxAPISessionsStub},
      retry: false
    )
  end
end
