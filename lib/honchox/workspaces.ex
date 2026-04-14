defmodule Honchox.Workspaces do
  @moduledoc """
  Workspace lifecycle and workspace-scoped operations.

  Workspaces are the top-level organizational unit in Honcho. Every peer,
  session, and conclusion belongs to a workspace.

  Functions that operate **on** a specific workspace (such as `search/3` or
  `queue_status/2`) require a `:workspace_id` option in the call. Functions
  that create or list workspaces operate at the account level.

  ## Examples

      client = Honchox.new(api_key: "sk-...")

      # Create or fetch a workspace
      {:ok, ws} = Honchox.Workspaces.get_or_create(client, "my-workspace",
        metadata: %{team: "platform"}
      )

      # Search within a workspace
      {:ok, results} = Honchox.Workspaces.search(client, "launch planning",
        workspace_id: "my-workspace",
        limit: 5
      )

  """

  @base_path "/v3/workspaces"

  @doc """
  Creates a new workspace or returns an existing one with the given `workspace_id`.

  ## Options

    * `:metadata` — arbitrary metadata map to attach to the workspace
    * `:configuration` — workspace configuration map

  ## Examples

      {:ok, workspace} = Honchox.Workspaces.get_or_create(client, "my-workspace",
        metadata: %{team: "alpha"},
        configuration: %{dream: %{enabled: true}}
      )

  """
  @spec get_or_create(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_or_create(%Honchox{} = client, workspace_id, attrs \\ []) do
    client
    |> Honchox.post(@base_path, attrs |> normalize_map() |> Map.put(:id, workspace_id))
  end

  @doc """
  Updates the workspace identified by `workspace_id`.

  Accepts the same options as `get_or_create/3` (`:metadata`, `:configuration`).
  Only the provided fields are updated.
  """
  @spec update(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update(%Honchox{} = client, workspace_id, attrs \\ []) do
    client
    |> Honchox.put("#{@base_path}/#{workspace_id}", normalize_map(attrs))
  end

  @doc """
  Deletes the workspace identified by `workspace_id`.
  """
  @spec delete(Honchox.t(), String.t()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Honchox{} = client, workspace_id) do
    Honchox.delete(client, "#{@base_path}/#{workspace_id}")
  end

  @doc """
  Lists workspaces with pagination and optional filters.

  ## Options

    * `:page` — page number (default: `1`)
    * `:size` — page size (default: `50`)
    * `:filters` — map of filter criteria (default: `%{}`)
  """
  @spec list(Honchox.t(), keyword() | map()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Honchox{} = client, opts \\ []) do
    opts = normalize_opts(opts)
    page = get_opt(opts, :page) || 1
    size = get_opt(opts, :size) || 50
    filters = get_opt(opts, :filters) || %{}

    path = "#{@base_path}/list?#{URI.encode_query(page: page, size: size)}"

    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  @doc """
  Searches within a workspace using a natural-language `query`.

  Requires `:workspace_id` in `opts`.

  ## Options

    * `:workspace_id` — the workspace to search in (**required**)
    * `:filters` — map of filter criteria (default: `%{}`)
    * `:limit` — max number of results (default: `10`)
  """
  @spec search(Honchox.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def search(%Honchox{} = client, query, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_map!(opts)

    body =
      opts
      |> normalize_map()
      |> Map.put(:query, query)
      |> Map.put_new(:filters, %{})
      |> Map.put_new(:limit, 10)

    Honchox.post(client, "#{@base_path}/#{workspace_id}/search", body)
  end

  @doc """
  Returns the processing queue status for a workspace.

  Requires `:workspace_id` in `opts`.

  ## Options

    * `:workspace_id` — the workspace to query (**required**)
    * `:observer_id` — filter by observer peer ID
    * `:sender_id` — filter by sender peer ID
    * `:session_id` — filter by session ID
  """
  @spec queue_status(Honchox.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def queue_status(%Honchox{} = client, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    Honchox.get(
      client,
      "#{@base_path}/#{workspace_id}/queue/status",
      queue_status_params(opts)
    )
  end

  @doc """
  Schedules a dream processing job for the workspace.

  Requires `:workspace_id` in `opts`.

  ## Options

    * `:workspace_id` — the workspace to schedule a dream for (**required**)
    * `:dream_type` — type of dream to schedule (default: `"omni"`)
  """
  @spec schedule_dream(Honchox.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def schedule_dream(%Honchox{} = client, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_map!(opts)

    body =
      opts
      |> normalize_map()
      |> Map.put_new(:dream_type, "omni")

    Honchox.post(client, "#{@base_path}/#{workspace_id}/schedule_dream", body)
  end

  defp workspace_scoped_opts!(value) do
    opts = normalize_opts(value)
    workspace_id = get_opt(opts, :workspace_id) || get_opt(opts, "workspace_id")

    if is_binary(workspace_id) do
      {workspace_id, Map.drop(opts, [:workspace_id, "workspace_id"])}
    else
      raise ArgumentError, "missing required workspace_id option"
    end
  end

  defp workspace_scoped_map!(value) do
    value = normalize_map(value)
    workspace_id = get_opt(value, :workspace_id) || get_opt(value, "workspace_id")

    if is_binary(workspace_id) do
      {workspace_id, Map.drop(value, [:workspace_id, "workspace_id"])}
    else
      raise ArgumentError, "missing required workspace_id option"
    end
  end

  defp queue_status_params(opts) do
    [
      observer_id: get_opt(opts, :observer_id),
      sender_id: get_opt(opts, :sender_id),
      session_id: get_opt(opts, :session_id)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp get_opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp get_opt(opts, key) when is_map(opts), do: Map.get(opts, key)

  defp normalize_opts(value) when is_map(value), do: value
  defp normalize_opts(value) when is_list(value), do: Map.new(value)
  defp normalize_opts(value), do: value

  defp normalize_map(value) when is_map(value), do: Map.new(value)
  defp normalize_map(value) when is_list(value), do: Map.new(value)
  defp normalize_map(value), do: value
end
