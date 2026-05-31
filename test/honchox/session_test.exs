defmodule Honchox.SessionTest do
  use ExUnit.Case

  import Req.Test

  setup :set_req_test_from_context
  setup {Req.Test, :verify_on_exit!}

  describe "lifecycle" do
    test "clone/2 ensures workspace, uses SDK clone query, and returns a Session struct" do
      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/clone"
        assert URI.decode_query(conn.query_string) == %{"message_id" => "msg-9"}
        assert conn.body_params == %{}

        Req.Test.json(conn, %{
          "id" => "session-2",
          "workspace_id" => "workspace-1",
          "metadata" => %{"topic" => "support"}
        })
      end)

      assert {:ok,
              %Honchox.Session{
                id: "session-2",
                workspace_id: "workspace-1",
                client: returned_client,
                metadata: %{"topic" => "support"}
              }} = Honchox.Session.clone(session(), message_id: "msg-9")

      assert returned_client == client()
    end

    test "delete/1 ensures workspace, deletes the session, and returns :ok" do
      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1"
        assert conn.query_string == ""

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok = Honchox.Session.delete(session())
    end
  end

  describe "peer membership" do
    test "peer membership methods normalize peer structs and return typed peers/config" do
      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"

        assert conn.body_params == %{
                 "alice" => %{},
                 "assistant" => %{}
               }

        Req.Test.json(conn, %{"items" => []})
      end)

      assert :ok = Honchox.Session.add_peers(session(), [%Honchox.Peer{id: "alice"}, "assistant"])

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"

        assert conn.body_params == %{
                 "alice" => %{"observe_me" => true},
                 "assistant" => %{"observe_others" => false}
               }

        Req.Test.json(conn, %{"items" => []})
      end)

      assert :ok =
               Honchox.Session.set_peers(session(), %{
                 "alice" => %{observe_me: true},
                 "assistant" => %{observe_others: false}
               })

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
        assert conn.body_params == %{"_json" => ["alice", "assistant"]}

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok =
               Honchox.Session.remove_peers(session(), [%Honchox.Peer{id: "alice"}, "assistant"])

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"

        Req.Test.json(conn, %{
          "items" => [%{"id" => "alice", "metadata" => %{"role" => "human"}}]
        })
      end)

      assert {:ok,
              [
                %Honchox.Peer{
                  id: "alice",
                  workspace_id: "workspace-1",
                  client: returned_client,
                  metadata: %{"role" => "human"}
                }
              ]} = Honchox.Session.peers(session())

      assert returned_client == client()

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "GET"

        assert conn.request_path ==
                 "/v3/workspaces/workspace-1/sessions/session-1/peers/alice/config"

        Req.Test.json(conn, %{"observe_me" => true, "observe_others" => false})
      end)

      assert {:ok, %{observe_me: true, observe_others: false}} =
               Honchox.Session.get_peer_configuration(session(), %Honchox.Peer{id: "alice"})

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "PUT"

        assert conn.request_path ==
                 "/v3/workspaces/workspace-1/sessions/session-1/peers/alice/config"

        assert conn.body_params == %{"observe_me" => true}
        Req.Test.json(conn, %{"observe_me" => true})
      end)

      assert :ok =
               Honchox.Session.set_peer_configuration(session(), %Honchox.Peer{id: "alice"},
                 observe_me: true
               )
    end

    test "set_peers/2 accepts SDK peer addition shapes and normalizes them to an API peer map" do
      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"

        assert conn.body_params == %{
                 "alice" => %{
                   "observe_me" => true,
                   "observe_others" => false
                 },
                 "assistant" => %{}
               }

        Req.Test.json(conn, %{"items" => []})
      end)

      assert :ok =
               Honchox.Session.set_peers(session(), [
                 {%Honchox.Peer{id: "alice"}, %{observe_me: true, observe_others: false}},
                 "assistant"
               ])
    end

    test "remove_peers/2 accepts a single peer value and normalizes it to a DELETE body list" do
      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/peers"
        assert conn.body_params == %{"_json" => ["alice"]}

        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok = Honchox.Session.remove_peers(session(), %Honchox.Peer{id: "alice"})
    end
  end

  describe "messages" do
    test "message methods normalize inputs and return Message/Page structs" do
      message_input =
        %Honchox.MessageInput{
          peer_id: "alice",
          content: "hello",
          metadata: %{source: "test"},
          configuration: %{visible: true},
          created_at: "2024-01-15T10:30:00Z"
        }

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
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

        Req.Test.json(conn, [%{"id" => "msg-1", "content" => "hello", "peer_id" => "alice"}])
      end)

      assert {:ok, [%Honchox.Message{id: "msg-1", content: "hello", peer_id: "alice"}]} =
               Honchox.Session.add_messages(session(), message_input)

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/list"

        assert URI.decode_query(conn.query_string) == %{
                 "page" => "2",
                 "reverse" => "true",
                 "size" => "20"
               }

        assert conn.body_params == %{"filters" => %{"peer_id" => "alice"}}

        Req.Test.json(conn, %{
          "items" => [%{"id" => "msg-1", "content" => "hello", "peer_id" => "alice"}],
          "total" => 1,
          "page" => 2,
          "size" => 20,
          "pages" => 1
        })
      end)

      assert {:ok,
              %Honchox.Page{
                items: [%Honchox.Message{id: "msg-1"}],
                total: 1,
                page: 2,
                size: 20,
                pages: 1
              }} =
               Honchox.Session.messages(session(),
                 page: 2,
                 size: 20,
                 reverse: true,
                 filters: %{peer_id: "alice"}
               )

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/msg-1"

        Req.Test.json(conn, %{"id" => "msg-1", "content" => "hello"})
      end)

      assert {:ok, %Honchox.Message{id: "msg-1", content: "hello"}} =
               Honchox.Session.get_message(session(), "msg-1")

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/messages/msg-1"
        assert conn.body_params == %{"metadata" => %{"reviewed" => true}}

        Req.Test.json(conn, %{"id" => "msg-1", "metadata" => %{"reviewed" => true}})
      end)

      assert {:ok, %Honchox.Message{id: "msg-1", metadata: %{"reviewed" => true}}} =
               Honchox.Session.update_message(session(), %Honchox.Message{id: "msg-1"}, %{
                 reviewed: true
               })

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "POST"

        assert conn.request_path ==
                 "/v3/workspaces/workspace-1/sessions/session-1/messages/upload"

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

        Req.Test.json(conn, [%{"id" => "msg-upload-1", "peer_id" => "alice"}])
      end)

      assert {:ok, [%Honchox.Message{id: "msg-upload-1", peer_id: "alice"}]} =
               Honchox.Session.upload_file(
                 session(),
                 {"notes.txt", "hello world"},
                 %Honchox.Peer{id: "alice"},
                 metadata: %{source: "upload"},
                 configuration: %{summarize: false},
                 created_at: "2024-01-15T10:30:00Z"
               )
    end
  end

  describe "context and search" do
    test "context/search methods use SDK endpoints and return known domain structs" do
      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/context"

        assert URI.decode_query(conn.query_string) == %{
                 "peer_perspective" => "assistant",
                 "peer_target" => "alice",
                 "search_query" => "billing",
                 "summary" => "true",
                 "tokens" => "800"
               }

        Req.Test.json(conn, %{
          "messages" => [%{"id" => "msg-1", "content" => "hello", "peer_id" => "alice"}],
          "summary" => %{"content" => "short", "summary_type" => "short"},
          "peer_representation" => "Prefers concise answers.",
          "peer_card" => ["concise"]
        })
      end)

      assert {:ok,
              %Honchox.SessionContext{
                session_id: "session-1",
                messages: [%Honchox.Message{id: "msg-1"}],
                summary: %Honchox.Summary{content: "short", summary_type: "short"},
                peer_representation: "Prefers concise answers.",
                peer_card: ["concise"]
              }} =
               Honchox.Session.context(session(),
                 tokens: 800,
                 summary: true,
                 search_query: %Honchox.Message{content: "billing"},
                 peer_target: %Honchox.Peer{id: "alice"},
                 peer_perspective: %Honchox.Peer{id: "assistant"}
               )

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/summaries"

        Req.Test.json(conn, %{
          "id" => "summaries-1",
          "short_summary" => %{"content" => "short", "summary_type" => "short"},
          "long_summary" => %{"content" => "long", "summary_type" => "long"}
        })
      end)

      assert {:ok,
              %{
                __struct__: Honchox.SessionSummaries,
                id: "summaries-1",
                short_summary: %Honchox.Summary{content: "short"},
                long_summary: %Honchox.Summary{content: "long"}
              }} = Honchox.Session.summaries(session())

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v3/workspaces/workspace-1/sessions/session-1/search"

        assert conn.body_params == %{
                 "query" => "refund",
                 "filters" => %{"kind" => "message"},
                 "limit" => 3
               }

        Req.Test.json(conn, [%{"id" => "msg-2", "content" => "refund policy"}])
      end)

      assert {:ok, [%Honchox.Message{id: "msg-2", content: "refund policy"}]} =
               Honchox.Session.search(session(), "refund", filters: %{kind: "message"}, limit: 3)

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v3/workspaces/workspace-1/queue/status"

        assert URI.decode_query(conn.query_string) == %{
                 "observer_id" => "assistant",
                 "sender_id" => "alice",
                 "session_id" => "session-1"
               }

        Req.Test.json(conn, %{"total_work_units" => 2, "pending_work_units" => 1})
      end)

      assert {:ok,
              %{
                __struct__: Honchox.QueueStatus,
                total_work_units: 2,
                pending_work_units: 1
              }} =
               Honchox.Session.queue_status(session(),
                 observer: %Honchox.Peer{id: "assistant"},
                 sender: %Honchox.Peer{id: "alice"}
               )

      expect_workspace_ensure()

      Req.Test.expect(HonchoxSessionStub, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v3/workspaces/workspace-1/peers/alice/representation"

        assert conn.body_params == %{
                 "session_id" => "session-1",
                 "target" => "assistant",
                 "search_query" => "prefs"
               }

        Req.Test.json(conn, %{"representation" => "Prefers tea."})
      end)

      assert {:ok, "Prefers tea."} =
               Honchox.Session.representation(session(), %Honchox.Peer{id: "alice"},
                 target: %Honchox.Peer{id: "assistant"},
                 search_query: %Honchox.Message{content: "prefs"}
               )
    end
  end

  defp expect_workspace_ensure(response_attrs \\ %{"id" => "workspace-1"}) do
    Req.Test.expect(HonchoxSessionStub, fn conn ->
      assert ["Bearer secret"] = Plug.Conn.get_req_header(conn, "authorization")
      assert conn.method == "POST"
      assert conn.request_path == "/v3/workspaces"
      assert conn.body_params == Map.take(response_attrs, ["id", "metadata", "configuration"])

      Req.Test.json(conn, response_attrs)
    end)
  end

  defp session do
    %Honchox.Session{id: "session-1", workspace_id: "workspace-1", client: client()}
  end

  defp client do
    Honchox.new(
      api_key: "secret",
      base_url: "https://api.honcho.dev",
      workspace_id: "workspace-1",
      plug: {Req.Test, HonchoxSessionStub},
      retry: false
    )
  end
end
