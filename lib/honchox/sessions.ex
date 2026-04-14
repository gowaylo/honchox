defmodule Honchox.Sessions do
  @moduledoc """
  Session endpoints for Honchox.
  """

  @base_path "/v3/workspaces"

  def get_or_create(%Honchox{} = client, session_id, attrs \\ []) do
    {workspace_id, attrs} = workspace_scoped_map!(attrs)

    Honchox.post(
      client,
      session_collection_path(workspace_id),
      attrs |> Map.put(:id, session_id)
    )
  end

  def update(%Honchox{} = client, session_id, attrs \\ []) do
    {workspace_id, attrs} = workspace_scoped_map!(attrs)
    Honchox.put(client, session_path(workspace_id, session_id), attrs)
  end

  def delete(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.delete(client, session_path(workspace_id, session_id))
  end

  def clone(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, opts} =
      opts
      |> workspace_scoped_map!()

    opts
    |> normalize_map()
    |> drop_nil_values()
    |> then(&Honchox.post(client, "#{session_path(workspace_id, session_id)}/clone", &1))
  end

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

  def summaries(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/summaries")
  end

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

  def add_peers(%Honchox{} = client, session_id, peers, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.post(client, "#{session_path(workspace_id, session_id)}/peers", %{peers: peers})
  end

  def set_peers(%Honchox{} = client, session_id, peers, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.put(client, "#{session_path(workspace_id, session_id)}/peers", %{peers: peers})
  end

  def remove_peers(%Honchox{} = client, session_id, peer_ids, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.delete(client, "#{session_path(workspace_id, session_id)}/peers",
      peer_ids: Enum.join(peer_ids, ",")
    )
  end

  def list_peers(%Honchox{} = client, session_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/peers")
  end

  def get_peer_config(%Honchox{} = client, session_id, peer_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/peers/#{peer_id}/config")
  end

  def set_peer_config(%Honchox{} = client, session_id, peer_id, config, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.put(
      client,
      "#{session_path(workspace_id, session_id)}/peers/#{peer_id}/config",
      normalize_map(config)
    )
  end

  def add_messages(%Honchox{} = client, session_id, messages, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.post(client, "#{session_path(workspace_id, session_id)}/messages", %{messages: messages})
  end

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

  def get_message(%Honchox{} = client, session_id, message_id, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.get(client, "#{session_path(workspace_id, session_id)}/messages/#{message_id}")
  end

  def update_message(%Honchox{} = client, session_id, message_id, attrs, opts \\ []) do
    {workspace_id, _opts} = workspace_scoped_opts!(opts)
    Honchox.put(
      client,
      "#{session_path(workspace_id, session_id)}/messages/#{message_id}",
      normalize_map(attrs)
    )
  end

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
