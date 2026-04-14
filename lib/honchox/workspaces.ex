defmodule Honchox.Workspaces do
  @moduledoc """
  Workspace endpoints for Honchox.
  """

  @base_path "/v3/workspaces"

  def get_or_create(%Honchox{} = client, workspace_id, attrs \\ []) do
    client
    |> Honchox.post(@base_path, attrs |> normalize_map() |> Map.put(:id, workspace_id))
  end

  def update(%Honchox{} = client, workspace_id, attrs \\ []) do
    client
    |> Honchox.put("#{@base_path}/#{workspace_id}", normalize_map(attrs))
  end

  def delete(%Honchox{} = client, workspace_id) do
    Honchox.delete(client, "#{@base_path}/#{workspace_id}")
  end

  def list(%Honchox{} = client, opts \\ []) do
    opts = normalize_opts(opts)
    page = get_opt(opts, :page) || 1
    size = get_opt(opts, :size) || 50
    filters = get_opt(opts, :filters) || %{}

    path = "#{@base_path}/list?#{URI.encode_query(page: page, size: size)}"

    Honchox.post(client, path, %{filters: normalize_map(filters)})
  end

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

  def queue_status(%Honchox{} = client, opts \\ []) do
    {workspace_id, opts} = workspace_scoped_opts!(opts)

    Honchox.get(
      client,
      "#{@base_path}/#{workspace_id}/queue/status",
      queue_status_params(opts)
    )
  end

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
