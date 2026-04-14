defmodule Honchox.Conclusions do
  @moduledoc """
  Conclusion endpoints for Honchox.
  """

  @base_path "/v3/workspaces"

  def list(%Honchox{} = client, opts \\ []) do
    opts = normalize_opts(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    filters = opt(opts, :filters) || %{}

    path = with_query("#{collection_path(client)}/list", page: page, size: size)
    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  def query(%Honchox{} = client, query, opts \\ []) do
    body =
      opts
      |> normalize_map()
      |> Map.put(:query, query)
      |> Map.put_new(:top_k, 10)
      |> Map.put_new(:distance, 0.5)
      |> Map.put_new(:filters, %{})

    Honchox.post(client, "#{collection_path(client)}/query", body)
  end

  def create(%Honchox{} = client, conclusions) do
    Honchox.post(client, collection_path(client), %{conclusions: conclusions})
  end

  def delete(%Honchox{} = client, conclusion_id) do
    Honchox.delete(client, "#{collection_path(client)}/#{conclusion_id}")
  end

  def representation(%Honchox{} = client, opts \\ []) do
    Honchox.post(client, "#{collection_path(client)}/representation", normalize_map(opts))
  end

  defp collection_path(%Honchox{workspace_id: workspace_id}) do
    "#{@base_path}/#{workspace_id}/conclusions"
  end

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

  defp with_query(path, query) when is_list(query) do
    case query do
      [] -> path
      _ -> "#{path}?#{URI.encode_query(query)}"
    end
  end
end
