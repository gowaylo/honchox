defmodule Honchox.API.Peers do
  @moduledoc false

  alias Honchox.Client
  alias Honchox.HTTP

  import Honchox.API.Helpers

  @spec get_or_create(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_or_create(%Client{} = client, peer_id, opts \\ []) do
    HTTP.post(client, "#{workspace_path(client)}/peers", body_with_id(peer_id, opts))
  end

  @spec update(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update(%Client{} = client, peer_id, attrs) do
    HTTP.put(client, peer_path(client, peer_id), compact(opts_to_map(attrs)))
  end

  @spec list(Client.t(), keyword() | map()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Client{} = client, opts \\ []) do
    HTTP.post(
      client,
      "#{workspace_path(client)}/peers/list",
      filters_body(opts),
      list_query(opts)
    )
  end

  @spec list_sessions(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def list_sessions(%Client{} = client, peer_id, opts \\ []) do
    HTTP.post(
      client,
      "#{peer_path(client, peer_id)}/sessions",
      filters_body(opts),
      list_query(opts)
    )
  end

  @spec chat(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def chat(%Client{} = client, peer_id, query, opts \\ []) do
    body =
      compact_map(
        query: query,
        stream: false,
        target: opt(opts, :target),
        session_id: opt(opts, :session_id),
        reasoning_level: opt(opts, :reasoning_level)
      )

    HTTP.post(client, "#{peer_path(client, peer_id)}/chat", body)
  end

  @spec search(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def search(%Client{} = client, peer_id, query, opts \\ []) do
    HTTP.post(client, "#{peer_path(client, peer_id)}/search", search_body(query, opts))
  end

  @spec representation(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def representation(%Client{} = client, peer_id, opts \\ []) do
    HTTP.post(client, "#{peer_path(client, peer_id)}/representation", compact(opts_to_map(opts)))
  end

  @spec context(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def context(%Client{} = client, peer_id, opts \\ []) do
    params =
      compact(
        target: opt(opts, :target),
        search_query: opt(opts, :search_query),
        search_top_k: opt(opts, :search_top_k),
        search_max_distance: opt(opts, :search_max_distance),
        include_most_frequent: opt(opts, :include_most_frequent),
        max_conclusions: opt(opts, :max_conclusions)
      )

    HTTP.get(client, "#{peer_path(client, peer_id)}/context", params)
  end

  @spec get_card(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_card(%Client{} = client, peer_id, opts \\ []) do
    HTTP.get(client, "#{peer_path(client, peer_id)}/card", compact(target: opt(opts, :target)))
  end

  @spec set_card(Client.t(), String.t(), [String.t()], keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def set_card(%Client{} = client, peer_id, peer_card, opts \\ []) do
    HTTP.put(
      client,
      "#{peer_path(client, peer_id)}/card",
      %{peer_card: peer_card},
      compact(target: opt(opts, :target))
    )
  end

  defp peer_path(%Client{} = client, peer_id), do: "#{workspace_path(client)}/peers/#{peer_id}"
end
