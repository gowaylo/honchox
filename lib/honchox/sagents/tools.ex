defmodule Honchox.Sagents.Tools do
  @moduledoc """
  Optional Sagents middleware exposing Honchox memory tools for conversation agents.

  Add `{:sagents, "~> 0.7", optional: true}` in applications that use this
  module, then include `Honchox.Sagents.Tools` in the Sagents middleware list.
  Configure it with either an existing `Honchox.Client` via `:client` or with
  `:client_opts` passed to `Honchox.new/1`.
  """

  @behaviour Sagents.Middleware

  alias LangChain.Function

  @impl true
  def init(opts) when is_list(opts) do
    client = Keyword.get(opts, :client) || Honchox.new(Keyword.get(opts, :client_opts, []))
    {:ok, %{client: client}}
  end

  @impl true
  def system_prompt(_config) do
    """
    You can use Honchox tools to retrieve and write durable conversation memory.
    Prefer semantic search and peer context before answering memory-dependent questions.
    Manual conclusions are deterministic memory; scheduled dreams enqueue async consolidation.
    """
  end

  @impl true
  def tools(config) do
    [
      search_messages_tool(config),
      get_peer_context_tool(config),
      create_conclusions_tool(config),
      schedule_dream_tool(config),
      queue_status_tool(config)
    ]
  end

  defp search_messages_tool(config) do
    Function.new!(%{
      name: "honchox_search_messages",
      description: "Search prior Honcho messages from an observer peer's perspective.",
      parameters_schema: %{
        type: "object",
        properties: %{
          observer_id: %{type: "string", description: "Peer doing the remembering/searching"},
          query: %{type: "string", description: "Semantic memory search query"},
          filters: %{type: "object", description: "Optional metadata filters"},
          limit: %{type: "integer", description: "Optional maximum number of matches"}
        },
        required: ["observer_id", "query"]
      },
      function: fn args, _context -> search_messages(args, config) end
    })
  end

  defp get_peer_context_tool(config) do
    Function.new!(%{
      name: "honchox_get_peer_context",
      description: "Get a peer's Honcho representation, card, and relevant conclusions.",
      parameters_schema: %{
        type: "object",
        properties: %{
          observer_id: %{type: "string"},
          target_id: %{type: "string"},
          search_query: %{type: "string"},
          max_conclusions: %{type: "integer"}
        },
        required: ["observer_id"]
      },
      function: fn args, _context -> get_peer_context(args, config) end
    })
  end

  defp create_conclusions_tool(config) do
    Function.new!(%{
      name: "honchox_create_conclusions",
      description: "Write deterministic Honcho conclusions for an observer/observed peer pair.",
      parameters_schema: %{
        type: "object",
        properties: %{
          observer_id: %{type: "string"},
          observed_id: %{type: "string"},
          conclusions: %{
            type: "array",
            items: %{
              oneOf: [
                %{type: "string"},
                %{
                  type: "object",
                  properties: %{content: %{type: "string"}, session_id: %{type: "string"}},
                  required: ["content"]
                }
              ]
            }
          }
        },
        required: ["observer_id", "observed_id", "conclusions"]
      },
      function: fn args, _context -> create_conclusions(args, config) end
    })
  end

  defp schedule_dream_tool(config) do
    Function.new!(%{
      name: "honchox_schedule_dream",
      description: "Schedule asynchronous Honcho dream consolidation for a peer representation.",
      parameters_schema: %{
        type: "object",
        properties: %{
          observer_id: %{type: "string"},
          observed_id: %{type: "string"},
          session_id: %{type: "string"}
        },
        required: ["observer_id"]
      },
      function: fn args, _context -> schedule_dream(args, config) end
    })
  end

  defp queue_status_tool(config) do
    Function.new!(%{
      name: "honchox_queue_status",
      description:
        "Check pending Honcho async work for the workspace or optional peer/session filters.",
      parameters_schema: %{
        type: "object",
        properties: %{
          observer_id: %{type: "string"},
          sender_id: %{type: "string"},
          session_id: %{type: "string"}
        }
      },
      function: fn args, _context -> queue_status(args, config) end
    })
  end

  defp search_messages(%{"observer_id" => observer_id, "query" => query} = args, %{client: client}) do
    with {:ok, messages} <-
           Honchox.Peer.search(peer(client, observer_id), query, common_opts(args)) do
      {:ok, %{messages: Enum.map(messages, &message_map/1)}}
    end
  end

  defp get_peer_context(%{"observer_id" => observer_id} = args, %{client: client}) do
    with {:ok, context} <- Honchox.Peer.context(peer(client, observer_id), common_opts(args)) do
      {:ok, Map.from_struct(context)}
    end
  end

  defp create_conclusions(
         %{
           "observer_id" => observer_id,
           "observed_id" => observed_id,
           "conclusions" => conclusions
         },
         %{client: client}
       ) do
    with {:ok, created} <-
           client
           |> peer(observer_id)
           |> Honchox.Peer.conclusions_of(observed_id)
           |> Honchox.ConclusionScope.create(conclusions) do
      {:ok, %{conclusions: Enum.map(created, &Map.from_struct/1)}}
    end
  end

  defp schedule_dream(%{"observer_id" => observer_id} = args, %{client: client}) do
    opts = common_opts(args)

    opts =
      case Map.get(args, "observed_id") do
        nil -> opts
        observed_id -> Keyword.put(opts, :observed, observed_id)
      end

    case Honchox.schedule_dream(client, observer_id, opts) do
      :ok -> {:ok, %{scheduled: true}}
      {:error, error} -> {:error, inspect(error)}
    end
  end

  defp queue_status(args, %{client: client}) do
    with {:ok, status} <- Honchox.queue_status(client, common_opts(args)) do
      {:ok, Map.from_struct(status)}
    end
  end

  defp common_opts(args) do
    []
    |> maybe_put(:target, args["target_id"])
    |> maybe_put(:session, args["session_id"])
    |> maybe_put(:search_query, args["search_query"])
    |> maybe_put(:max_conclusions, args["max_conclusions"])
    |> maybe_put(:filters, args["filters"])
    |> maybe_put(:limit, args["limit"])
    |> maybe_put(:observer, args["observer_id"])
    |> maybe_put(:sender, args["sender_id"])
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp peer(client, peer_id) do
    %Honchox.Peer{id: peer_id, workspace_id: client.workspace_id, client: client}
  end

  defp message_map(message) do
    message
    |> Map.from_struct()
    |> Map.drop([:metadata, :created_at, :token_count])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
