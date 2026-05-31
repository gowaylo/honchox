defmodule Honchox.Peer do
  @moduledoc """
  Public peer resource converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t(),
          client: Honchox.Client.t() | nil,
          metadata: map() | nil,
          configuration: map() | nil,
          created_at: term() | nil
        }

  defstruct [:id, :workspace_id, :client, :metadata, :configuration, :created_at]

  import Honchox.API.Helpers, only: [opt: 2, opts_to_map: 1]

  alias Honchox.API.Peers, as: PeerAPI

  @spec from_api(Honchox.Client.t() | nil, String.t(), map()) :: t()
  def from_api(client, workspace_id, data) when is_map(data) do
    %__MODULE__{
      id: opt(data, :id),
      workspace_id: workspace_id,
      client: client,
      metadata: opt(data, :metadata),
      configuration: opt(data, :configuration),
      created_at: opt(data, :created_at)
    }
  end

  @spec message(t(), String.t(), keyword() | map()) :: Honchox.MessageInput.t()
  def message(%__MODULE__{} = peer, content, opts \\ []) do
    %Honchox.MessageInput{
      peer_id: peer.id,
      content: content,
      metadata: opt(opts, :metadata),
      configuration: opt(opts, :configuration),
      created_at: opt(opts, :created_at)
    }
  end

  @spec conclusions(t()) :: Honchox.ConclusionScope.t()
  def conclusions(%__MODULE__{} = peer), do: conclusions_of(peer, peer)

  @spec conclusions_of(t(), t() | String.t()) :: Honchox.ConclusionScope.t()
  def conclusions_of(%__MODULE__{} = observer, observed) do
    %Honchox.ConclusionScope{
      client: observer.client,
      workspace_id: observer.workspace_id,
      observer_id: observer.id,
      observed_id: id_or_self(observed)
    }
  end

  @spec chat(t(), String.t(), keyword() | map()) ::
          {:ok, String.t() | nil} | {:error, Honchox.Error.t()}
  def chat(%__MODULE__{client: client, id: peer_id} = peer, query, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- PeerAPI.chat(client, peer_id, query, normalize_opts(peer, opts)) do
      {:ok, present_content(opt(data, :content))}
    end
  end

  @spec search(t(), String.t(), keyword() | map()) ::
          {:ok, [Honchox.Message.t()]} | {:error, Honchox.Error.t()}
  def search(%__MODULE__{client: client, id: peer_id} = peer, query, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- PeerAPI.search(client, peer_id, query, normalize_opts(peer, opts)) do
      {:ok, Enum.map(data, &Honchox.Message.from_api/1)}
    end
  end

  @spec representation(t(), keyword() | map()) ::
          {:ok, String.t() | nil} | {:error, Honchox.Error.t()}
  def representation(%__MODULE__{client: client, id: peer_id} = peer, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- PeerAPI.representation(client, peer_id, normalize_opts(peer, opts)) do
      {:ok, opt(data, :representation)}
    end
  end

  @spec context(t(), keyword() | map()) ::
          {:ok, Honchox.PeerContext.t()} | {:error, Honchox.Error.t()}
  def context(%__MODULE__{client: client, id: peer_id} = peer, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- PeerAPI.context(client, peer_id, normalize_opts(peer, opts)) do
      {:ok, Honchox.PeerContext.from_api(data)}
    end
  end

  @spec get_card(t(), keyword() | map()) ::
          {:ok, [String.t()] | nil} | {:error, Honchox.Error.t()}
  def get_card(%__MODULE__{client: client, id: peer_id} = peer, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- PeerAPI.get_card(client, peer_id, normalize_opts(peer, opts)) do
      {:ok, opt(data, :peer_card)}
    end
  end

  @spec set_card(t(), [String.t()], keyword() | map()) ::
          {:ok, [String.t()] | nil} | {:error, Honchox.Error.t()}
  def set_card(%__MODULE__{client: client, id: peer_id} = peer, card, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(client),
         {:ok, data} <- PeerAPI.set_card(client, peer_id, card, normalize_opts(peer, opts)) do
      {:ok, opt(data, :peer_card)}
    end
  end

  defp normalize_opts(%__MODULE__{}, opts) do
    opts
    |> opts_to_map()
    |> Map.update(:target, nil, &id_or_self/1)
    |> Map.update(:session, nil, &id_or_self/1)
    |> Map.update(:search_query, nil, &content_or_self/1)
    |> rename(:session, :session_id)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp id_or_self(%__MODULE__{id: id}), do: id
  defp id_or_self(%Honchox.Session{id: id}), do: id
  defp id_or_self(value), do: value

  defp content_or_self(%Honchox.Message{content: content}), do: content
  defp content_or_self(value), do: value

  defp rename(opts, from, to) do
    case Map.pop(opts, from) do
      {nil, opts} -> opts
      {value, opts} -> Map.put(opts, to, value)
    end
  end

  defp present_content(""), do: nil
  defp present_content(nil), do: nil
  defp present_content(content), do: content
end
