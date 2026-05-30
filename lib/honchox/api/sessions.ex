defmodule Honchox.API.Sessions do
  @moduledoc false

  alias Honchox.Client
  alias Honchox.HTTP

  import Honchox.API.Helpers

  @spec list(Client.t(), keyword() | map()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Client{} = client, opts \\ []) do
    HTTP.post(
      client,
      "#{workspace_path(client)}/sessions/list",
      filters_body(opts),
      list_query(opts)
    )
  end

  @spec get_or_create(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_or_create(%Client{} = client, session_id, opts \\ []) do
    HTTP.post(client, "#{workspace_path(client)}/sessions", body_with_id(session_id, opts))
  end

  @spec update(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update(%Client{} = client, session_id, attrs) do
    HTTP.put(client, session_path(client, session_id), compact(opts_to_map(attrs)))
  end

  @spec delete(Client.t(), String.t()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Client{} = client, session_id) do
    HTTP.delete(client, session_path(client, session_id))
  end

  @spec clone(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def clone(%Client{} = client, session_id, opts \\ []) do
    HTTP.post_query(
      client,
      "#{session_path(client, session_id)}/clone",
      compact(message_id: opt(opts, :message_id))
    )
  end

  @spec context(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def context(%Client{} = client, session_id, opts \\ []) do
    HTTP.get(client, "#{session_path(client, session_id)}/context", compact(opts_to_map(opts)))
  end

  @spec summaries(Client.t(), String.t()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def summaries(%Client{} = client, session_id) do
    HTTP.get(client, "#{session_path(client, session_id)}/summaries")
  end

  @spec search(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def search(%Client{} = client, session_id, query, opts \\ []) do
    HTTP.post(client, "#{session_path(client, session_id)}/search", search_body(query, opts))
  end

  @spec add_peers(Client.t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def add_peers(%Client{} = client, session_id, peers) do
    HTTP.post(client, "#{session_path(client, session_id)}/peers", peers)
  end

  @spec set_peers(Client.t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def set_peers(%Client{} = client, session_id, peers) do
    HTTP.put(client, "#{session_path(client, session_id)}/peers", peers)
  end

  @spec remove_peers(Client.t(), String.t(), [String.t()]) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def remove_peers(%Client{} = client, session_id, peer_ids) do
    HTTP.delete_json(client, "#{session_path(client, session_id)}/peers", peer_ids)
  end

  @spec list_peers(Client.t(), String.t()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list_peers(%Client{} = client, session_id) do
    HTTP.get(client, "#{session_path(client, session_id)}/peers")
  end

  @spec get_peer_config(Client.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_peer_config(%Client{} = client, session_id, peer_id) do
    HTTP.get(client, "#{session_path(client, session_id)}/peers/#{peer_id}/config")
  end

  @spec set_peer_config(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def set_peer_config(%Client{} = client, session_id, peer_id, config) do
    HTTP.put(
      client,
      "#{session_path(client, session_id)}/peers/#{peer_id}/config",
      compact(opts_to_map(config))
    )
  end

  @spec add_messages(Client.t(), String.t(), [map()]) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def add_messages(%Client{} = client, session_id, messages) do
    HTTP.post(client, "#{session_path(client, session_id)}/messages", %{messages: messages})
  end

  @spec list_messages(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def list_messages(%Client{} = client, session_id, opts \\ []) do
    HTTP.post(
      client,
      "#{session_path(client, session_id)}/messages/list",
      filters_body(opts),
      list_query(opts)
    )
  end

  @spec get_message(Client.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_message(%Client{} = client, session_id, message_id) do
    HTTP.get(client, "#{session_path(client, session_id)}/messages/#{message_id}")
  end

  @spec update_message(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update_message(%Client{} = client, session_id, message_id, opts \\ []) do
    HTTP.put(client, "#{session_path(client, session_id)}/messages/#{message_id}", %{
      metadata: opt(opts, :metadata) || %{}
    })
  end

  @spec upload_file(Client.t(), String.t(), {String.t(), binary()}, keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def upload_file(%Client{} = client, session_id, {filename, content}, opts \\ []) do
    fields =
      compact(
        file: {content, filename: filename},
        peer_id: opt(opts, :peer_id),
        metadata: json_field(opt(opts, :metadata)),
        configuration: json_field(opt(opts, :configuration)),
        created_at: opt(opts, :created_at)
      )

    HTTP.upload(client, "#{session_path(client, session_id)}/messages/upload", fields)
  end

  @spec queue_status(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def queue_status(%Client{} = client, session_id, opts \\ []) do
    params =
      compact(
        session_id: session_id,
        observer_id: opt(opts, :observer_id),
        sender_id: opt(opts, :sender_id)
      )

    HTTP.get(client, "#{workspace_path(client)}/queue/status", params)
  end

  @spec representation(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def representation(%Client{} = client, session_id, peer_id, opts \\ []) do
    body =
      opts
      |> opts_to_map()
      |> Map.put(:session_id, session_id)
      |> compact()

    HTTP.post(client, "#{workspace_path(client)}/peers/#{peer_id}/representation", body)
  end

  defp session_path(%Client{} = client, session_id),
    do: "#{workspace_path(client)}/sessions/#{session_id}"

  defp json_field(nil), do: nil
  defp json_field(value), do: Jason.encode!(value)
end
