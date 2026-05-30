defmodule Honchox.API.Helpers do
  @moduledoc false

  @base_path "/v3/workspaces"

  def workspace_path(%Honchox.Client{workspace_id: workspace_id}),
    do: "#{@base_path}/#{workspace_id}"

  def workspace_path(workspace_id) when is_binary(workspace_id),
    do: "#{@base_path}/#{workspace_id}"

  def opt(opts, key) when is_map(opts) do
    cond do
      Map.has_key?(opts, key) -> Map.get(opts, key)
      Map.has_key?(opts, Atom.to_string(key)) -> Map.get(opts, Atom.to_string(key))
      true -> nil
    end
  end

  def opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)

  def opts_to_map(value) when is_map(value), do: Map.new(value)
  def opts_to_map(value) when is_list(value), do: Map.new(value)

  def compact(value) when is_map(value) do
    value
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Map.new()
  end

  def compact(value) when is_list(value) do
    Enum.reject(value, fn {_key, val} -> is_nil(val) end)
  end

  def compact_map(value), do: value |> compact() |> Map.new()

  def list_query(opts) do
    compact(
      page: opt(opts, :page) || 1,
      size: opt(opts, :size) || 50,
      reverse: if(opt(opts, :reverse), do: true)
    )
  end

  def filters_body(opts), do: %{filters: opt(opts, :filters) || %{}}

  def body_with_id(id, opts) do
    opts
    |> opts_to_map()
    |> Map.put(:id, id)
    |> compact_map()
  end

  def search_body(query, opts) do
    compact_map(
      query: query,
      filters: opt(opts, :filters),
      limit: opt(opts, :limit)
    )
  end
end
