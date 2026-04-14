defmodule Honchox.Sessions do
  @moduledoc """
  Session lifecycle, messages, peer membership, context, and file uploads.

  A **session** is a conversation thread within a workspace. Sessions contain
  messages, can have multiple peer participants, and accumulate context that
  can be retrieved or searched.

  All functions require a `:workspace_id` option.

  ## Examples

      client = Honchox.new(api_key: "sk-...")

      # Create or fetch a session
      {:ok, session} = Honchox.Sessions.get_or_create(client, "session-1",
        workspace_id: "my-workspace",
        metadata: %{topic: "onboarding"}
      )

      # Add messages
      {:ok, msgs} = Honchox.Sessions.add_messages(client, "session-1", [
        %{peer_id: "alice", content: "Hello!"},
        %{peer_id: "bot", content: "Hi Alice, how can I help?"}
      ], workspace_id: "my-workspace")

      # Get session context
      {:ok, ctx} = Honchox.Sessions.context(client, "session-1",
        workspace_id: "my-workspace"
      )

  """

  @base_path "/v3/workspaces"

  # ---------------------------------------------------------------------------
  # Session lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new session or returns an existing one with the given `session_id`.

  ## Options

    * `:workspace_id` — (**required**)
    * `:metadata` — arbitrary metadata map
    * `:configuration` — session configuration map
  """
  @spec get_or_create(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_or_create(%Honchox{} = client, session_id, attrs \\ []) do
    {workspace_id, attrs} = workspace_scoped_map!(attrs)

    Honchox.post(
      client,
      session_collection_path(workspace_id),
      attrs |> Map.put(:id, session_id)
    )
  end

  @doc """
  Updates the session identified by `session_id`.

  ## Options

    * `:workspace_id` — (**required**)
    * `:metadata` — updated metadata map
    * `:configuration` — updated configuration map
  """
  @spec update(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update(%Honchox{} = client, session_id, attrs \\ []) do
    {workspace_id, attrs} = workspace_scoped_map!(attrs)
    Honchox.put(client, session_path(workspace_id, session_id), attrs)
  end

  @doc """
  Deletes the session identified by `session_id`.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec delete(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.delete(client, session_path(workspace_id, session_id))
  end

  @doc """
  Clones an existing session, optionally from a specific message point.

  ## Options

    * `:workspace_id` — (**required**)
    * `:message_id` — clone from this message onward (optional)
  """
  @spec clone(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def clone(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, opts} =
      opts
      |> workspace_scoped_map!()

    opts
    |> normalize_map()
    |> drop_nil_values()
    |> then(&Honchox.post(client, "#{session_path(workspace_id, session_id)}/clone", &1))
  end

  # ---------------------------------------------------------------------------
  # Context & search
  # ---------------------------------------------------------------------------

  @doc """
  Returns the accumulated context for a session.

  Context includes conversation summaries, peer conclusions, and semantic
  search results depending on the options provided.

  ## Options

    * `:workspace_id` — (**required**)
    * `:summary` — include conversation summary
    * `:tokens` — token budget for context
    * `:peer_target` — target peer ID
    * `:peer_perspective` — perspective peer ID
    * `:search_query` — semantic search query
    * `:limit_to_session` — restrict search to this session only
    * `:search_top_k` — number of top search results
    * `:search_max_distance` — maximum cosine distance
    * `:include_most_frequent` — include most frequently referenced conclusions
    * `:max_conclusions` — cap on total conclusions
  """
  @spec context(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def context(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    query =
      [
        summary: opt(opts, :summary),
        tokens: opt(opts, :tokens),
        peer_target: opt(opts, :peer_target),
        peer_perspective: opt(opts, :peer_perspective),
        search_query: opt(opts, :search_query),
        limit_to_session: opt(opts, :limit_to_session),
        search_top_k: opt(opts, :search_top_k),
        search_max_distance: opt(opts, :search_max_distance),
        include_most_frequent: opt(opts, :include_most_frequent),
        max_conclusions: opt(opts, :max_conclusions)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Honchox.get(client, with_query("#{session_path(workspace_id, session_id)}/context", query))
  end

  @doc """
  Returns available summaries for a session.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec summaries(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def summaries(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/summaries")
  end

  @doc """
  Searches session content using a natural-language `query`.

  ## Options

    * `:workspace_id` — (**required**)
    * `:filters` — map of filter criteria (default: `%{}`)
    * `:limit` — max number of results (default: `10`)
  """
  @spec search(Honchox.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def search(%Honchox{} = client, session_id, query, opts \\ []) do
    {workspace_id, body} =
      opts
      |> workspace_scoped_map!()

    body =
      body
      |> Map.put(:query, query)
      |> Map.put_new(:filters, %{})
      |> Map.put_new(:limit, 10)
      |> drop_nil_values()

    Honchox.post(client, "#{session_path(workspace_id, session_id)}/search", body)
  end

  # ---------------------------------------------------------------------------
  # Peer membership
  # ---------------------------------------------------------------------------

  @doc """
  Adds peers to a session.

  `peers` is a list of peer specification maps (e.g., `[%{id: "alice"}]`).

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec add_peers(Honchox.t(), String.t(), [map()], keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def add_peers(%Honchox{} = client, session_id, peers, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.post(client, "#{session_path(workspace_id, session_id)}/peers", %{peers: peers})
  end

  @doc """
  Replaces the entire peer list for a session.

  `peers` is a list of peer specification maps.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec set_peers(Honchox.t(), String.t(), [map()], keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def set_peers(%Honchox{} = client, session_id, peers, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.put(client, "#{session_path(workspace_id, session_id)}/peers", %{peers: peers})
  end

  @doc """
  Removes peers from a session by their IDs.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec remove_peers(Honchox.t(), String.t(), [String.t()], keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def remove_peers(%Honchox{} = client, session_id, peer_ids, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.delete(client, "#{session_path(workspace_id, session_id)}/peers",
      peer_ids: Enum.join(peer_ids, ",")
    )
  end

  @doc """
  Lists all peers participating in a session.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec list_peers(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, [map()]} | {:error, Honchox.Error.t()}
  def list_peers(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/peers")
  end

  @doc """
  Gets the session-level configuration for a specific peer.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec get_peer_config(Honchox.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_peer_config(%Honchox{} = client, session_id, peer_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/peers/#{peer_id}/config")
  end

  @doc """
  Updates the session-level configuration for a specific peer.

  `config` is a map of configuration values to set.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec set_peer_config(Honchox.t(), String.t(), String.t(), map() | keyword(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def set_peer_config(%Honchox{} = client, session_id, peer_id, config, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.put(
      client,
      "#{session_path(workspace_id, session_id)}/peers/#{peer_id}/config",
      normalize_map(config)
    )
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  @doc """
  Adds a batch of messages to a session.

  `messages` is a list of message maps. Each message should include at least
  `:peer_id` and `:content`.

  ## Options

    * `:workspace_id` — (**required**)

  ## Examples

      {:ok, msgs} = Honchox.Sessions.add_messages(client, "session-1", [
        %{peer_id: "alice", content: "Hello!"},
        %{peer_id: "bot", content: "Hi there!"}
      ], workspace_id: "my-workspace")

  """
  @spec add_messages(Honchox.t(), String.t(), [map()], keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def add_messages(%Honchox{} = client, session_id, messages, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.post(client, "#{session_path(workspace_id, session_id)}/messages", %{messages: messages})
  end

  @doc """
  Lists messages in a session with pagination.

  ## Options

    * `:workspace_id` — (**required**)
    * `:page` — page number (default: `1`)
    * `:size` — page size (default: `50`)
    * `:reverse` — reverse chronological order
    * `:filters` — map of filter criteria (default: `%{}`)
  """
  @spec list_messages(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def list_messages(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    reverse = opt(opts, :reverse)
    filters = opt(opts, :filters) || %{}

    query =
      [page: page, size: size, reverse: reverse]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    path = with_query("#{session_path(workspace_id, session_id)}/messages/list", query)
    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  @doc """
  Gets a single message by its `message_id`.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec get_message(Honchox.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_message(%Honchox{} = client, session_id, message_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/messages/#{message_id}")
  end

  @doc """
  Updates a message's payload.

  `attrs` is a map of fields to update on the message.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec update_message(Honchox.t(), String.t(), String.t(), map() | keyword(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update_message(%Honchox{} = client, session_id, message_id, attrs, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.put(
      client,
      "#{session_path(workspace_id, session_id)}/messages/#{message_id}",
      normalize_map(attrs)
    )
  end

  # ---------------------------------------------------------------------------
  # Files
  # ---------------------------------------------------------------------------

  @doc """
  Uploads a file to a session as a multipart form request.

  The file is passed as a `{filename, content}` tuple where `content` is
  the raw binary data.

  ## Options

    * `:workspace_id` — (**required**)
    * `:peer` — peer ID to associate the file with
    * `:metadata` — metadata map (JSON-encoded automatically)
    * `:created_at` — custom creation timestamp
  """
  @spec upload_file(Honchox.t(), String.t(), {String.t(), binary()}, keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def upload_file(%Honchox{} = client, session_id, {filename, content}, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    fields =
      [
        file: {content, filename: filename},
        peer: opt(opts, :peer),
        metadata: metadata_field(opt(opts, :metadata)),
        created_at: opt(opts, :created_at)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Honchox.upload(client, "#{session_path(workspace_id, session_id)}/files", fields)
  end

  # ---------------------------------------------------------------------------
  # Queue & representation
  # ---------------------------------------------------------------------------

  @doc """
  Returns the processing queue status for a session.

  ## Options

    * `:workspace_id` — (**required**)
    * `:observer_id` — filter by observer peer ID
    * `:sender_id` — filter by sender peer ID
  """
  @spec queue_status(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def queue_status(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    query =
      [
        observer_id: opt(opts, :observer_id),
        sender_id: opt(opts, :sender_id)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Honchox.get(client, with_query("#{session_path(workspace_id, session_id)}/queue/status", query))
  end

  @doc """
  Returns a peer's representation within the scope of a session.

  ## Options

    * `:workspace_id` — (**required**)
    * `:target` — target peer ID
    * `:search_query` — semantic search query
    * `:search_top_k` — number of top results
    * `:include_most_frequent` — include most frequently referenced conclusions
    * `:max_conclusions` — cap on total conclusions
  """
  @spec representation(Honchox.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def representation(%Honchox{} = client, session_id, peer_id, opts \\ []) do
    {workspace_id, body} =
      opts
      |> workspace_scoped_map!()

    body =
      body
      |> Map.put(:peer_id, peer_id)
      |> drop_nil_values()

    Honchox.post(client, "#{session_path(workspace_id, session_id)}/representation", body)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp session_collection_path(workspace_id), do: "#{@base_path}/#{workspace_id}/sessions"

  defp session_path(workspace_id, session_id), do: "#{session_collection_path(workspace_id)}/#{session_id}"

  defp metadata_field(nil), do: nil
  defp metadata_field(value), do: Jason.encode!(value)

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

  defp with_query(path, query) when is_map(query), do: with_query(path, Map.to_list(query))
  defp with_query(path, _query), do: path
end
