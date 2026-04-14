defmodule Honchox.Peers do
  @moduledoc """
  Peer lifecycle, chat, context, representation, and card endpoints.

  A **peer** represents a participant in a Honcho workspace — typically a user
  or an AI agent. Peers are scoped to a workspace and can participate in
  sessions, accumulate context, and have associated cards.

  All functions require a `:workspace_id` option.

  ## Examples

      client = Honchox.new(api_key: "sk-...")

      # Create or fetch a peer
      {:ok, peer} = Honchox.Peers.get_or_create(client, "alice",
        workspace_id: "my-workspace",
        metadata: %{role: "user"}
      )

      # Chat with peer context
      {:ok, response} = Honchox.Peers.chat(client, "alice", "What was our last topic?",
        workspace_id: "my-workspace"
      )

      # Get curated peer representation
      {:ok, repr} = Honchox.Peers.representation(client, "alice",
        workspace_id: "my-workspace"
      )

  """

  @base_path "/v3/workspaces"

  @doc """
  Creates a new peer or returns an existing one with the given `peer_id`.

  ## Options

    * `:workspace_id` — the workspace this peer belongs to (**required**)
    * `:metadata` — arbitrary metadata map
    * `:configuration` — peer configuration map
  """
  @spec get_or_create(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_or_create(%Honchox{} = client, peer_id, attrs \\ []) do
    {workspace_id, attrs} = workspace_scoped_map!(attrs)

    client
    |> Honchox.post(
      peer_collection_path(workspace_id),
      attrs |> Map.put(:id, peer_id)
    )
  end

  @doc """
  Updates the peer identified by `peer_id`.

  ## Options

    * `:workspace_id` — (**required**)
    * `:metadata` — updated metadata map
    * `:configuration` — updated configuration map
  """
  @spec update(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update(%Honchox{} = client, peer_id, attrs \\ []) do
    {workspace_id, attrs} = workspace_scoped_map!(attrs)

    client
    |> Honchox.put(peer_path(workspace_id, peer_id), attrs)
  end

  @doc """
  Lists peers in a workspace with pagination and optional filters.

  ## Options

    * `:workspace_id` — (**required**)
    * `:page` — page number (default: `1`)
    * `:size` — page size (default: `50`)
    * `:filters` — map of filter criteria (default: `%{}`)
  """
  @spec list(Honchox.t(), keyword() | map()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Honchox{} = client, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    filters = opt(opts, :filters) || %{}

    path = with_query("#{peer_collection_path(workspace_id)}/list", page: page, size: size)

    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  @doc """
  Lists sessions that the given `peer_id` participates in.

  ## Options

    * `:workspace_id` — (**required**)
    * `:page` — page number (default: `1`)
    * `:size` — page size (default: `50`)
    * `:filters` — map of filter criteria (default: `%{}`)
  """
  @spec list_sessions(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def list_sessions(%Honchox{} = client, peer_id, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    filters = opt(opts, :filters) || %{}

    path = with_query("#{peer_path(workspace_id, peer_id)}/sessions", page: page, size: size)

    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  @doc """
  Sends a chat message with peer context and returns an AI response.

  ## Options

    * `:workspace_id` — (**required**)
    * `:reasoning_level` — reasoning depth for the AI response
    * `:session_id` — session to scope the chat to
    * `:target` — target peer ID for directed chat
  """
  @spec chat(Honchox.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def chat(%Honchox{} = client, peer_id, query, opts \\ []) do
    {workspace_id, body} =
      opts
      |> workspace_scoped_map!()

    body =
      body
      |> Map.put(:query, query)
      |> drop_nil_values()

    Honchox.post(client, "#{peer_path(workspace_id, peer_id)}/chat", body)
  end

  @doc """
  Searches peer context using a natural-language `query`.

  ## Options

    * `:workspace_id` — (**required**)
    * `:filters` — map of filter criteria (default: `%{}`)
    * `:limit` — max number of results (default: `10`)
  """
  @spec search(Honchox.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def search(%Honchox{} = client, peer_id, query, opts \\ []) do
    {workspace_id, body} =
      opts
      |> workspace_scoped_map!()

    body =
      body
      |> Map.put(:query, query)
      |> Map.put_new(:filters, %{})
      |> Map.put_new(:limit, 10)
      |> drop_nil_values()

    Honchox.post(client, "#{peer_path(workspace_id, peer_id)}/search", body)
  end

  @doc """
  Returns a curated representation of the peer built from their conclusions
  and context via semantic search.

  ## Options

    * `:workspace_id` — (**required**)
    * `:search_query` — semantic search query for filtering conclusions
    * `:search_top_k` — number of top results to include
    * `:search_max_distance` — maximum cosine distance threshold
    * `:include_most_frequent` — include most frequently referenced conclusions
    * `:max_conclusions` — cap on total conclusions in representation
    * `:target` — target peer ID
  """
  @spec representation(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def representation(%Honchox{} = client, peer_id, opts \\ []) do
    {workspace_id, body} =
      opts
      |> workspace_scoped_map!()

    Honchox.post(client, "#{peer_path(workspace_id, peer_id)}/representation", drop_nil_values(body))
  end

  @doc """
  Returns the peer's accumulated context.

  ## Options

    * `:workspace_id` — (**required**)
    * `:target` — target peer ID
    * `:search_query` — semantic search query
    * `:search_top_k` — number of top results
    * `:search_max_distance` — maximum cosine distance
    * `:include_most_frequent` — include most frequently referenced conclusions
    * `:max_conclusions` — cap on total conclusions
  """
  @spec context(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def context(%Honchox{} = client, peer_id, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    query =
      [
        target: opt(opts, :target),
        search_query: opt(opts, :search_query),
        search_top_k: opt(opts, :search_top_k),
        search_max_distance: opt(opts, :search_max_distance),
        include_most_frequent: opt(opts, :include_most_frequent),
        max_conclusions: opt(opts, :max_conclusions)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Honchox.get(client, with_query("#{peer_path(workspace_id, peer_id)}/context", query))
  end

  @doc """
  Gets the peer card for the given `peer_id`.

  Peer cards are profile-like summaries that describe a peer from the
  perspective of another peer.

  ## Options

    * `:workspace_id` — (**required**)
    * `:target` — the observing peer's ID (whose perspective to use)
  """
  @spec get_card(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_card(%Honchox{} = client, peer_id, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    query =
      [target: opt(opts, :target)]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Honchox.get(client, with_query("#{peer_path(workspace_id, peer_id)}/card", query))
  end

  @doc """
  Sets or updates the peer card for the given `peer_id`.

  ## Parameters

    * `peer_card` — the card content to set (string or map)

  ## Options

    * `:workspace_id` — (**required**)
    * `:target` — the observing peer's ID (whose perspective to set)
  """
  @spec set_card(Honchox.t(), String.t(), term(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def set_card(%Honchox{} = client, peer_id, peer_card, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    query =
      [target: opt(opts, :target)]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    body = %{peer_card: peer_card}

    Honchox.put(client, with_query("#{peer_path(workspace_id, peer_id)}/card", query), body)
  end

  defp peer_collection_path(workspace_id), do: "#{@base_path}/#{workspace_id}/peers"

  defp peer_path(workspace_id, peer_id), do: "#{peer_collection_path(workspace_id)}/#{peer_id}"

  defp opt(opts, key) when is_map(opts) do
    cond do
      Map.has_key?(opts, key) -> Map.get(opts, key)
      Map.has_key?(opts, Atom.to_string(key)) -> Map.get(opts, Atom.to_string(key))
      true -> nil
    end
  end

  defp opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)

  defp normalize_opts(value) when is_map(value), do: value
  defp normalize_opts(value) when is_list(value), do: Map.new(value)
  defp normalize_opts(value), do: value

  defp normalize_map(value) when is_map(value), do: Map.new(value)
  defp normalize_map(value) when is_list(value), do: Map.new(value)
  defp normalize_map(value), do: value

  defp workspace_scoped_opts!(value) do
    opts = normalize_opts(value)
    workspace_id = opt(opts, :workspace_id)

    if is_binary(workspace_id) do
      {workspace_id, Map.drop(opts, [:workspace_id, "workspace_id"])}
    else
      raise ArgumentError, "missing required workspace_id option"
    end
  end

  defp workspace_scoped_map!(value) do
    value = normalize_map(value)
    workspace_id = opt(value, :workspace_id)

    if is_binary(workspace_id) do
      {workspace_id, Map.drop(value, [:workspace_id, "workspace_id"])}
    else
      raise ArgumentError, "missing required workspace_id option"
    end
  end

  defp drop_nil_values(value) when is_map(value) do
    value
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Map.new()
  end

  defp drop_nil_values(value), do: value

  defp with_query(path, query) when is_list(query) do
    case query do
      [] -> path
      _ -> "#{path}?#{URI.encode_query(query)}"
    end
  end

  defp with_query(path, query) when is_map(query) do
    with_query(path, Map.to_list(query))
  end

  defp with_query(path, query) when is_binary(query) and query != "", do: "#{path}?#{query}"
  defp with_query(path, _query), do: path
end
