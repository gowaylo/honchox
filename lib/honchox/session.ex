defmodule Honchox.Session do
  @moduledoc """
  Public session resource converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t(),
          client: Honchox.Client.t() | nil,
          metadata: map() | nil,
          configuration: map() | nil,
          created_at: term() | nil,
          is_active: boolean() | nil
        }

  defstruct [:id, :workspace_id, :client, :metadata, :configuration, :created_at, :is_active]

  import Honchox.API.Helpers, only: [opt: 2, opts_to_map: 1]

  alias Honchox.API.Sessions, as: SessionAPI

  @spec from_api(Honchox.Client.t() | nil, String.t(), map()) :: t()
  def from_api(client, workspace_id, data) when is_map(data) do
    %__MODULE__{
      id: opt(data, :id),
      workspace_id: workspace_id,
      client: client,
      metadata: opt(data, :metadata),
      configuration: opt(data, :configuration),
      created_at: opt(data, :created_at),
      is_active: opt(data, :is_active)
    }
  end

  @spec clone(t(), keyword() | map()) :: {:ok, t()} | {:error, Honchox.Error.t()}
  def clone(%__MODULE__{client: client, id: session_id} = session, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.clone(client, session_id, normalize_opts(opts)) do
      {:ok, from_api(client, session.workspace_id, data)}
    end
  end

  @spec delete(t()) :: :ok | {:error, Honchox.Error.t()}
  def delete(%__MODULE__{client: client, id: session_id}) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, _data} <- SessionAPI.delete(client, session_id) do
      :ok
    end
  end

  @spec add_peers(t(), term()) :: :ok | {:error, Honchox.Error.t()}
  def add_peers(%__MODULE__{client: client, id: session_id}, peers) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, _data} <- SessionAPI.add_peers(client, session_id, peer_additions_payload(peers)) do
      :ok
    end
  end

  @spec set_peers(t(), term()) :: :ok | {:error, Honchox.Error.t()}
  def set_peers(%__MODULE__{client: client, id: session_id}, peers) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, _data} <- SessionAPI.set_peers(client, session_id, peer_additions_payload(peers)) do
      :ok
    end
  end

  @spec remove_peers(t(), term()) :: :ok | {:error, Honchox.Error.t()}
  def remove_peers(%__MODULE__{client: client, id: session_id}, peers) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, _data} <- SessionAPI.remove_peers(client, session_id, peer_removal_ids(peers)) do
      :ok
    end
  end

  @spec peers(t()) :: {:ok, [Honchox.Peer.t()]} | {:error, Honchox.Error.t()}
  def peers(%__MODULE__{client: client, id: session_id, workspace_id: workspace_id}) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.list_peers(client, session_id) do
      {:ok, Enum.map(opt(data, :items) || [], &Honchox.Peer.from_api(client, workspace_id, &1))}
    end
  end

  @spec get_peer_configuration(t(), Honchox.Peer.t() | String.t()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_peer_configuration(%__MODULE__{client: client, id: session_id}, peer) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.get_peer_config(client, session_id, peer_id(peer)) do
      {:ok, atomize_keys(data)}
    end
  end

  @spec set_peer_configuration(t(), Honchox.Peer.t() | String.t(), keyword() | map()) ::
          :ok | {:error, Honchox.Error.t()}
  def set_peer_configuration(%__MODULE__{client: client, id: session_id}, peer, config) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, _data} <- SessionAPI.set_peer_config(client, session_id, peer_id(peer), config) do
      :ok
    end
  end

  @spec add_messages(t(), Honchox.MessageInput.t() | [Honchox.MessageInput.t() | map()]) ::
          {:ok, [Honchox.Message.t()]} | {:error, Honchox.Error.t()}
  def add_messages(%__MODULE__{client: client, id: session_id}, messages) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.add_messages(client, session_id, normalize_messages(messages)) do
      {:ok, Enum.map(data, &Honchox.Message.from_api/1)}
    end
  end

  @spec messages(t(), keyword() | map()) ::
          {:ok, Honchox.Page.t(Honchox.Message.t())} | {:error, Honchox.Error.t()}
  def messages(%__MODULE__{client: client, id: session_id}, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.list_messages(client, session_id, normalize_opts(opts)) do
      {:ok, Honchox.Page.from_api(data, &Honchox.Message.from_api/1)}
    end
  end

  @spec get_message(t(), Honchox.Message.t() | String.t()) ::
          {:ok, Honchox.Message.t()} | {:error, Honchox.Error.t()}
  def get_message(%__MODULE__{client: client, id: session_id}, message) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.get_message(client, session_id, message_id(message)) do
      {:ok, Honchox.Message.from_api(data)}
    end
  end

  @spec update_message(t(), Honchox.Message.t() | String.t(), keyword() | map()) ::
          {:ok, Honchox.Message.t()} | {:error, Honchox.Error.t()}
  def update_message(%__MODULE__{client: client, id: session_id}, message, attrs) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <-
           SessionAPI.update_message(client, session_id, message_id(message), metadata: attrs) do
      {:ok, Honchox.Message.from_api(data)}
    end
  end

  @spec upload_file(t(), {String.t(), binary()}, Honchox.Peer.t() | String.t(), keyword() | map()) ::
          {:ok, [Honchox.Message.t()]} | {:error, Honchox.Error.t()}
  def upload_file(%__MODULE__{client: client, id: session_id}, file, peer, opts \\ []) do
    opts = opts |> normalize_opts() |> Map.put(:peer_id, peer_id(peer))

    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.upload_file(client, session_id, file, opts) do
      {:ok, Enum.map(data, &Honchox.Message.from_api/1)}
    end
  end

  @spec context(t(), keyword() | map()) ::
          {:ok, Honchox.SessionContext.t()} | {:error, Honchox.Error.t()}
  def context(%__MODULE__{client: client, id: session_id}, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.context(client, session_id, normalize_opts(opts)) do
      {:ok, Honchox.SessionContext.from_api(session_id, data)}
    end
  end

  @spec summaries(t()) :: {:ok, Honchox.SessionSummaries.t()} | {:error, Honchox.Error.t()}
  def summaries(%__MODULE__{client: client, id: session_id}) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.summaries(client, session_id) do
      {:ok, Honchox.SessionSummaries.from_api(data)}
    end
  end

  @spec search(t(), String.t(), keyword() | map()) ::
          {:ok, [Honchox.Message.t()]} | {:error, Honchox.Error.t()}
  def search(%__MODULE__{client: client, id: session_id}, query, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.search(client, session_id, query, normalize_opts(opts)) do
      {:ok, Enum.map(data, &Honchox.Message.from_api/1)}
    end
  end

  @spec queue_status(t(), keyword() | map()) ::
          {:ok, Honchox.QueueStatus.t()} | {:error, Honchox.Error.t()}
  def queue_status(%__MODULE__{client: client, id: session_id}, opts \\ []) do
    opts =
      opts
      |> normalize_opts()
      |> rename(:observer, :observer_id)
      |> rename(:sender, :sender_id)

    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- SessionAPI.queue_status(client, session_id, opts) do
      {:ok, Honchox.QueueStatus.from_api(data)}
    end
  end

  @spec representation(t(), Honchox.Peer.t() | String.t(), keyword() | map()) ::
          {:ok, String.t() | nil} | {:error, Honchox.Error.t()}
  def representation(%__MODULE__{client: client, id: session_id}, peer, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <-
           SessionAPI.representation(client, session_id, peer_id(peer), normalize_opts(opts)) do
      {:ok, opt(data, :representation)}
    end
  end

  defp normalize_messages(messages) when is_list(messages),
    do: Enum.map(messages, &message_body/1)

  defp normalize_messages(message), do: [message_body(message)]

  defp message_body(%Honchox.MessageInput{} = message) do
    message
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp message_body(message) when is_map(message), do: message

  defp normalize_opts(opts) do
    opts
    |> opts_to_map()
    |> Map.update(:peer_target, nil, &peer_id/1)
    |> Map.update(:peer_perspective, nil, &peer_id/1)
    |> Map.update(:target, nil, &peer_id/1)
    |> Map.update(:observer, nil, &peer_id/1)
    |> Map.update(:sender, nil, &peer_id/1)
    |> Map.update(:search_query, nil, &content_or_self/1)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp peer_additions_payload(peers) when is_list(peers) do
    Map.new(peers, &peer_addition_entry/1)
  end

  defp peer_additions_payload(peers) when is_map(peers) and not is_struct(peers) do
    Map.new(peers, fn {peer, config} -> {peer_id(peer), normalize_peer_config(config)} end)
  end

  defp peer_additions_payload(peer), do: Map.new([peer], &peer_addition_entry/1)

  defp peer_addition_entry({peer, config}), do: {peer_id(peer), normalize_peer_config(config)}
  defp peer_addition_entry(peer), do: {peer_id(peer), %{}}

  defp normalize_peer_config(nil), do: %{}

  defp normalize_peer_config(config) do
    config
    |> opts_to_map()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {peer_config_key(key), value} end)
  end

  defp peer_config_key(key) when is_atom(key), do: key |> Atom.to_string() |> Macro.underscore()
  defp peer_config_key(key) when is_binary(key), do: Macro.underscore(key)
  defp peer_config_key(key), do: key

  defp peer_removal_ids(peers) when is_list(peers), do: Enum.map(peers, &peer_id/1)
  defp peer_removal_ids(peer), do: [peer_id(peer)]

  defp peer_id(%Honchox.Peer{id: id}), do: id
  defp peer_id(value), do: value

  defp message_id(%Honchox.Message{id: id}), do: id
  defp message_id(value), do: value

  defp content_or_self(%Honchox.Message{content: content}), do: content
  defp content_or_self(value), do: value

  defp rename(opts, from, to) do
    case Map.pop(opts, from) do
      {nil, opts} -> opts
      {value, opts} -> Map.put(opts, to, value)
    end
  end

  defp atomize_keys(data) when is_map(data) do
    Map.new(data, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      entry -> entry
    end)
  end
end

defmodule Honchox.SessionSummaries do
  @moduledoc """
  Public session summaries converted from Honcho API responses.
  """

  defstruct [:id, :short_summary, :long_summary]

  import Honchox.API.Helpers, only: [opt: 2]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          short_summary: Honchox.Summary.t() | nil,
          long_summary: Honchox.Summary.t() | nil
        }

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: opt(data, :id),
      short_summary: summary_from_api(opt(data, :short_summary)),
      long_summary: summary_from_api(opt(data, :long_summary))
    }
  end

  defp summary_from_api(nil), do: nil
  defp summary_from_api(data) when is_map(data), do: Honchox.Summary.from_api(data)
end

defmodule Honchox.QueueStatus do
  @moduledoc """
  Public queue status converted from Honcho API responses.
  """

  defstruct [:total_work_units, :pending_work_units]

  import Honchox.API.Helpers, only: [opt: 2]

  @type t :: %__MODULE__{
          total_work_units: integer() | nil,
          pending_work_units: integer() | nil
        }

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      total_work_units: opt(data, :total_work_units),
      pending_work_units: opt(data, :pending_work_units)
    }
  end
end
