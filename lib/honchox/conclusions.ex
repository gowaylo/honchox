defmodule Honchox.Conclusions do
  @moduledoc """
  Conclusion endpoints for Honchox.
  """

  @base_path "/v3/workspaces"

  def list(%Honchox{} = client, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    filters = opt(opts, :filters) || %{}

    path = with_query("#{collection_path(workspace_id)}/list", page: page, size: size)
    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  def query(%Honchox{} = client, query, opts \\ []) do
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

  def create(%Honchox{} = client, conclusions, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.post(client, collection_path(workspace_id), %{conclusions: conclusions})
  end

  def delete(%Honchox{} = client, conclusion_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.delete(client, "#{collection_path(workspace_id)}/#{conclusion_id}")
  end

  def representation(%Honchox{} = client, opts \\ []) do
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
