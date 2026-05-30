defmodule Honchox.API.Workspaces do
  @moduledoc false

  alias Honchox.Client
  alias Honchox.HTTP

  import Honchox.API.Helpers

  @base_path "/v3/workspaces"

  @spec get_or_create(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def get_or_create(%Client{} = client, workspace_id, opts \\ []) do
    HTTP.post(client, @base_path, body_with_id(workspace_id, opts))
  end

  @spec update(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def update(%Client{} = client, workspace_id, attrs) do
    HTTP.put(client, workspace_path(workspace_id), compact(opts_to_map(attrs)))
  end

  @spec delete(Client.t(), String.t()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Client{} = client, workspace_id) do
    HTTP.delete(client, workspace_path(workspace_id))
  end

  @spec list(Client.t(), keyword() | map()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Client{} = client, opts \\ []) do
    HTTP.post(client, "#{@base_path}/list", filters_body(opts), list_query(opts))
  end

  @spec search(Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def search(%Client{} = client, query, opts \\ []) do
    HTTP.post(client, "#{workspace_path(client)}/search", search_body(query, opts))
  end

  @spec queue_status(Client.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def queue_status(%Client{} = client, opts \\ []) do
    HTTP.get(
      client,
      "#{workspace_path(client)}/queue/status",
      compact(
        observer_id: opt(opts, :observer_id),
        sender_id: opt(opts, :sender_id),
        session_id: opt(opts, :session_id)
      )
    )
  end

  @spec schedule_dream(Client.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def schedule_dream(%Client{} = client, opts \\ []) do
    observer_id = opt(opts, :observer_id)

    body =
      compact_map(
        observer: observer_id,
        observed: opt(opts, :observed_id) || observer_id,
        session_id: opt(opts, :session_id),
        dream_type: "omni"
      )

    HTTP.post(client, "#{workspace_path(client)}/schedule_dream", body)
  end
end
