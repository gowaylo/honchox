defmodule Honchox.Peers do
  @moduledoc """
  Peer endpoints for Honchox.
  """

  @base_path "/v3/workspaces"

  def get_or_create(%Honchox{} = client, peer_id, attrs \\ []) do
    client
    |> Honchox.post(
      peer_collection_path(client),
      attrs |> normalize_map() |> Map.put(:id, peer_id)
    )
  end

  def update(%Honchox{} = client, peer_id, attrs \\ []) do
    client
    |> Honchox.put(peer_path(client, peer_id), normalize_map(attrs))
  end

  def list(%Honchox{} = client, opts \\ []) do
    opts = normalize_opts(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    filters = opt(opts, :filters) || %{}

    path = with_query("#{peer_collection_path(client)}/list", page: page, size: size)

    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  def list_sessions(%Honchox{} = client, peer_id, opts \\ []) do
    opts = normalize_opts(opts)
    page = opt(opts, :page) || 1
    size = opt(opts, :size) || 50
    filters = opt(opts, :filters) || %{}

    path = with_query("#{peer_path(client, peer_id)}/sessions", page: page, size: size)

    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

  def chat(%Honchox{} = client, peer_id, query, opts \\ []) do
    body =
      opts
      |> normalize_map()
      |> Map.put(:query, query)
      |> drop_nil_values()

    Honchox.post(client, "#{peer_path(client, peer_id)}/chat", body)
  end

  def search(%Honchox{} = client, peer_id, query, opts \\ []) do
    body =
      opts
      |> normalize_map()
      |> Map.put(:query, query)
      |> Map.put_new(:filters, %{})
      |> Map.put_new(:limit, 10)
      |> drop_nil_values()

    Honchox.post(client, "#{peer_path(client, peer_id)}/search", body)
  end

  def representation(%Honchox{} = client, peer_id, opts \\ []) do
    body =
      opts
      |> normalize_map()
      |> drop_nil_values()

    Honchox.post(client, "#{peer_path(client, peer_id)}/representation", body)
  end

  def context(%Honchox{} = client, peer_id, opts \\ []) do
    opts = normalize_opts(opts)

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

    Honchox.get(client, with_query("#{peer_path(client, peer_id)}/context", query))
  end

  def get_card(%Honchox{} = client, peer_id, opts \\ []) do
    opts = normalize_opts(opts)

    query =
      [target: opt(opts, :target)]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Honchox.get(client, with_query("#{peer_path(client, peer_id)}/card", query))
  end

  def set_card(%Honchox{} = client, peer_id, peer_card, opts \\ []) do
    opts = normalize_opts(opts)

    query =
      [target: opt(opts, :target)]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    body = %{peer_card: peer_card}

    Honchox.put(client, with_query("#{peer_path(client, peer_id)}/card", query), body)
  end

  defp peer_collection_path(%Honchox{workspace_id: workspace_id}) do
    "#{@base_path}/#{workspace_id}/peers"
  end

  defp peer_path(%Honchox{} = client, peer_id) do
    "#{peer_collection_path(client)}/#{peer_id}"
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
