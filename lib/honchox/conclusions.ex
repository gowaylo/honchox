defmodule Honchox.Conclusions do
  @moduledoc """
  Conclusion CRUD and semantic search endpoints.

  **Conclusions** are persistent observations that Honcho derives from
  conversations. They capture facts, preferences, and patterns about peers
  and are used to build context and representations.

  All functions require a `:workspace_id` option.

  ## Examples

      client = Honchox.new(api_key: "sk-...")

      # Create conclusions
      {:ok, created} = Honchox.Conclusions.create(client, [
        %{content: "Prefers concise answers", observer_id: "bot", observed_id: "alice"}
      ], workspace_id: "my-workspace")

      # Semantic search
      {:ok, results} = Honchox.Conclusions.query(client, "communication preferences",
        workspace_id: "my-workspace",
        top_k: 5
      )

      # List with pagination
      {:ok, page} = Honchox.Conclusions.list(client,
        workspace_id: "my-workspace",
        page: 1,
        size: 20
      )

  """

  @base_path "/v3/workspaces"

  @doc """
  Lists conclusions with pagination and optional filters.

  ## Options

    * `:workspace_id` — (**required**)
    * `:page` — page number (default: `1`)
    * `:size` — page size (default: `50`)
    * `:filters` — map of filter criteria (default: `%{}`)
  """
  @spec list(Honchox.Client.t(), keyword() | map()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Honchox.Client{} = client, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    filters = opt(opts, :filters) || %{}

    path = with_query("#{collection_path(workspace_id)}/list", page: page, size: size)
    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  @doc """
  Performs a semantic search over conclusions using a natural-language `query`.

  ## Options

    * `:workspace_id` — (**required**)
    * `:top_k` — number of top results to return (default: `10`)
    * `:distance` — maximum cosine distance threshold (default: `0.5`)
    * `:filters` — map of filter criteria (default: `%{}`)
  """
  @spec query(Honchox.Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def query(%Honchox.Client{} = client, query, opts \\ []) do
    {workspace_id, body} =
      opts
      |> workspace_scoped_map!()

    body =
      body
      |> Map.put(:query, query)
      |> Map.put_new(:top_k, 10)
      |> Map.put_new(:distance, 0.5)
      |> Map.put_new(:filters, %{})

    Honchox.post(client, "#{collection_path(workspace_id)}/query", body)
  end

  @doc """
  Creates one or more conclusions.

  `conclusions` is a list of conclusion maps. Each map should include at least
  `:content`, `:observer_id`, and `:observed_id`.

  ## Options

    * `:workspace_id` — (**required**)

  ## Examples

      {:ok, created} = Honchox.Conclusions.create(client, [
        %{
          content: "Enjoys hiking on weekends",
          observer_id: "bot",
          observed_id: "alice"
        }
      ], workspace_id: "my-workspace")

  """
  @spec create(Honchox.Client.t(), [map()], keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def create(%Honchox.Client{} = client, conclusions, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.post(client, collection_path(workspace_id), %{conclusions: conclusions})
  end

  @doc """
  Deletes a conclusion by its `conclusion_id`.

  ## Options

    * `:workspace_id` — (**required**)
  """
  @spec delete(Honchox.Client.t(), String.t(), keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Honchox.Client{} = client, conclusion_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.delete(client, "#{collection_path(workspace_id)}/#{conclusion_id}")
  end

  @doc """
  Generates a workspace-level representation from conclusions.

  ## Options

    * `:workspace_id` — (**required**)
    * `:observer_id` — filter by observer peer ID
    * `:observed_id` — filter by observed peer ID
    * `:session_id` — filter by session ID
  """
  @spec representation(Honchox.Client.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def representation(%Honchox.Client{} = client, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_map!(opts)
    Honchox.post(client, "#{collection_path(workspace_id)}/representation", opts)
  end

  defp collection_path(workspace_id), do: "#{@base_path}/#{workspace_id}/conclusions"

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

  defp with_query(path, query) when is_list(query) do
    case query do
      [] -> path
      _ -> "#{path}?#{URI.encode_query(query)}"
    end
  end
end
