defmodule Honchox.StructsTest do
  use ExUnit.Case, async: true

  test "from_api converts raw API maps into public resource structs" do
    client = Honchox.new(api_key: "sk-test", workspace_id: "workspace-1")

    peer =
      Honchox.Peer.from_api(client, "workspace-1", %{
        "id" => "peer-1",
        "metadata" => %{"role" => "user"},
        "configuration" => %{"model" => "claude"},
        "created_at" => "2026-05-30T00:00:00Z"
      })

    assert_struct(peer, Honchox.Peer)
    assert peer.id == "peer-1"
    assert peer.workspace_id == "workspace-1"
    assert peer.client == client
    assert peer.metadata == %{"role" => "user"}
    assert peer.configuration == %{"model" => "claude"}
    assert peer.created_at == "2026-05-30T00:00:00Z"
    refute_raw_payload_field(peer)

    session =
      Honchox.Session.from_api(client, "workspace-1", %{
        id: "session-1",
        metadata: %{"topic" => "support"},
        configuration: %{"temperature" => 0.2},
        created_at: "2026-05-30T00:01:00Z",
        is_active: true
      })

    assert_struct(session, Honchox.Session)
    assert session.id == "session-1"
    assert session.workspace_id == "workspace-1"
    assert session.client == client
    assert session.is_active == true
    assert session.metadata == %{"topic" => "support"}
    assert session.configuration == %{"temperature" => 0.2}
    refute_raw_payload_field(session)

    message =
      Honchox.Message.from_api(%{
        "id" => "message-1",
        "content" => "hello",
        "peer_id" => "peer-1",
        "session_id" => "session-1",
        "workspace_id" => "workspace-1",
        "metadata" => %{"trace" => "kept"},
        "created_at" => "2026-05-30T00:02:00Z",
        "token_count" => 3
      })

    assert_struct(message, Honchox.Message)
    assert message.id == "message-1"
    assert message.content == "hello"
    assert message.peer_id == "peer-1"
    assert message.session_id == "session-1"
    assert message.workspace_id == "workspace-1"
    assert message.metadata == %{"trace" => "kept"}
    assert message.created_at == "2026-05-30T00:02:00Z"
    assert message.token_count == 3
    refute_raw_payload_field(message)

    conclusion =
      Honchox.Conclusion.from_api(%{
        "id" => "conclusion-1",
        "content" => "Alice likes tea",
        "observer_id" => "observer-1",
        "observed_id" => "observed-1",
        "session_id" => "session-1",
        "created_at" => "2026-05-30T00:03:00Z"
      })

    assert_struct(conclusion, Honchox.Conclusion)
    assert conclusion.id == "conclusion-1"
    assert conclusion.content == "Alice likes tea"
    assert conclusion.observer_id == "observer-1"
    assert conclusion.observed_id == "observed-1"
    assert conclusion.session_id == "session-1"
    assert conclusion.created_at == "2026-05-30T00:03:00Z"
    refute_raw_payload_field(conclusion)
  end

  test "context and page conversions convert nested known API maps without leaking raw maps" do
    peer_context =
      Honchox.PeerContext.from_api(%{
        "peer_id" => "peer-1",
        "target_id" => "peer-2",
        "representation" => "friendly",
        "peer_card" => ["likes tea"]
      })

    assert_struct(peer_context, Honchox.PeerContext)
    assert peer_context.peer_id == "peer-1"
    assert peer_context.target_id == "peer-2"
    assert peer_context.representation == "friendly"
    assert peer_context.peer_card == ["likes tea"]
    refute_raw_payload_field(peer_context)

    session_context =
      Honchox.SessionContext.from_api("session-1", %{
        "messages" => [
          %{
            "id" => "message-1",
            "content" => "hello",
            "peer_id" => "peer-1",
            "session_id" => "session-1",
            "workspace_id" => "workspace-1",
            "metadata" => %{"source" => "api"},
            "created_at" => "2026-05-30T00:04:00Z",
            "token_count" => 2
          }
        ],
        "summary" => %{
          "content" => "greeting",
          "message_id" => "message-0",
          "summary_type" => "short",
          "created_at" => "2026-05-30T00:05:00Z",
          "token_count" => 1
        },
        "peer_representation" => "helpful",
        "peer_card" => ["concise"]
      })

    assert_struct(session_context, Honchox.SessionContext)
    assert session_context.session_id == "session-1"
    assert [%{__struct__: Honchox.Message} = nested_message] = session_context.messages
    assert nested_message.metadata == %{"source" => "api"}
    assert_struct(session_context.summary, Honchox.Summary)
    assert session_context.summary.content == "greeting"
    assert session_context.summary.message_id == "message-0"
    assert session_context.summary.summary_type == "short"
    assert session_context.summary.created_at == "2026-05-30T00:05:00Z"
    assert session_context.summary.token_count == 1
    assert session_context.peer_representation == "helpful"
    assert session_context.peer_card == ["concise"]
    refute_raw_payload_field(session_context)

    page =
      Honchox.Page.from_api(
        %{
          "items" => [
            %{
              "id" => "message-2",
              "content" => "paged",
              "peer_id" => "peer-1",
              "session_id" => "session-1",
              "workspace_id" => "workspace-1",
              "metadata" => %{"kept" => true},
              "token_count" => 4
            }
          ],
          "total" => 1,
          "page" => 1,
          "size" => 20,
          "pages" => 1
        },
        &Honchox.Message.from_api/1
      )

    assert_struct(page, Honchox.Page)
    assert page.page == 1
    assert page.size == 20
    assert page.total == 1
    assert page.pages == 1
    assert [%{__struct__: Honchox.Message} = paged_message] = page.items
    assert paged_message.content == "paged"
    assert paged_message.metadata == %{"kept" => true}
    refute is_map_key(paged_message, "content")
    refute_raw_payload_field(page)
  end

  defp assert_struct(value, module) do
    assert %{__struct__: ^module} = value
  end

  defp refute_raw_payload_field(struct) do
    refute Map.has_key?(struct, :api_map)
    refute Map.has_key?(struct, :data)
    refute Map.has_key?(struct, :raw)
    refute Map.has_key?(struct, :raw_api)
  end
end
