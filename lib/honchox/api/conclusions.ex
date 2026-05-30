defmodule Honchox.API.Conclusions do
  @moduledoc false

  alias Honchox.Client
  alias Honchox.HTTP

  import Honchox.API.Helpers

  @spec list(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Client{} = client, observer_id, observed_id, opts \\ []) do
    filters =
      compact_map(
        observer_id: observer_id,
        observed_id: observed_id,
        session_id: opt(opts, :session_id)
      )

    HTTP.post(
      client,
      "#{workspace_path(client)}/conclusions/list",
      %{filters: filters},
      list_query(opts)
    )
  end

  @spec query(Client.t(), String.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def query(%Client{} = client, observer_id, observed_id, query, opts \\ []) do
    body =
      compact_map(
        query: query,
        top_k: opt(opts, :top_k) || 10,
        distance: opt(opts, :distance),
        filters: %{observer_id: observer_id, observed_id: observed_id}
      )

    HTTP.post(client, "#{workspace_path(client)}/conclusions/query", body)
  end

  @spec create(Client.t(), String.t(), String.t(), [String.t()], keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def create(%Client{} = client, observer_id, observed_id, conclusions, opts \\ []) do
    body = %{
      conclusions:
        Enum.map(conclusions, fn conclusion ->
          %{
            content: conclusion,
            observer_id: observer_id,
            observed_id: observed_id,
            session_id: opt(opts, :session_id)
          }
        end)
    }

    HTTP.post(client, "#{workspace_path(client)}/conclusions", body)
  end

  @spec delete(Client.t(), String.t()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Client{} = client, conclusion_id) do
    HTTP.delete(client, "#{workspace_path(client)}/conclusions/#{conclusion_id}")
  end

  @spec representation(Client.t(), String.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def representation(%Client{} = client, observer_id, observed_id, opts \\ []) do
    body =
      opts
      |> opts_to_map()
      |> Map.put(:target, observed_id)
      |> compact()

    HTTP.post(client, "#{workspace_path(client)}/peers/#{observer_id}/representation", body)
  end
end
