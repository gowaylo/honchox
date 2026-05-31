defmodule Honchox.ConclusionScope do
  @moduledoc """
  Peer-scoped conclusion operations.
  """

  alias Honchox.API.Conclusions, as: ConclusionAPI

  import Honchox.API.Helpers, only: [opt: 2, opts_to_map: 1]

  @type t :: %__MODULE__{
          client: Honchox.Client.t(),
          workspace_id: String.t(),
          observer_id: String.t(),
          observed_id: String.t()
        }

  defstruct [:client, :workspace_id, :observer_id, :observed_id]

  @spec list(t(), keyword() | map()) ::
          {:ok, Honchox.Page.t(Honchox.Conclusion.t())} | {:error, Honchox.Error.t()}
  def list(%__MODULE__{} = scope, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(scope.client),
         {:ok, data} <-
           ConclusionAPI.list(
             scope.client,
             scope.observer_id,
             scope.observed_id,
             normalize_opts(opts)
           ) do
      {:ok, Honchox.Page.from_api(data, &Honchox.Conclusion.from_api/1)}
    end
  end

  @spec query(t(), String.t(), keyword() | map()) ::
          {:ok, [Honchox.Conclusion.t()]} | {:error, Honchox.Error.t()}
  def query(%__MODULE__{} = scope, query, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(scope.client),
         {:ok, data} <-
           ConclusionAPI.query(
             scope.client,
             scope.observer_id,
             scope.observed_id,
             query,
             normalize_opts(opts)
           ) do
      {:ok, Enum.map(data, &Honchox.Conclusion.from_api/1)}
    end
  end

  @spec create(t(), String.t() | map() | [String.t() | map()]) ::
          {:ok, [Honchox.Conclusion.t()]} | {:error, Honchox.Error.t()}
  def create(%__MODULE__{} = scope, conclusions) do
    conclusions = conclusions |> List.wrap() |> Enum.map(&normalize_conclusion(scope, &1))

    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(scope.client),
         {:ok, data} <-
           ConclusionAPI.create(scope.client, scope.observer_id, scope.observed_id, conclusions) do
      {:ok, Enum.map(data, &Honchox.Conclusion.from_api/1)}
    end
  end

  @spec delete(t(), String.t()) :: :ok | {:error, Honchox.Error.t()}
  def delete(%__MODULE__{} = scope, conclusion_id) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(scope.client),
         {:ok, _data} <- ConclusionAPI.delete(scope.client, conclusion_id) do
      :ok
    end
  end

  @spec representation(t(), keyword() | map()) ::
          {:ok, String.t() | nil} | {:error, Honchox.Error.t()}
  def representation(%__MODULE__{} = scope, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- Honchox.workspace(scope.client),
         {:ok, data} <-
           ConclusionAPI.representation(
             scope.client,
             scope.observer_id,
             scope.observed_id,
             normalize_opts(opts)
           ) do
      {:ok, opt(data, :representation)}
    end
  end

  defp normalize_opts(opts) do
    opts
    |> opts_to_map()
    |> Map.update(:session, nil, &id_or_self/1)
    |> Map.update(:search_query, nil, &content_or_self/1)
    |> rename(:session, :session_id)
  end

  defp normalize_conclusion(scope, content) when is_binary(content) do
    %{
      content: content,
      observer_id: scope.observer_id,
      observed_id: scope.observed_id,
      session_id: nil
    }
  end

  defp normalize_conclusion(scope, conclusion) when is_map(conclusion) do
    %{
      content: opt(conclusion, :content),
      observer_id: scope.observer_id,
      observed_id: scope.observed_id,
      session_id: opt(conclusion, :session_id) || id_or_self(opt(conclusion, :session))
    }
  end

  defp id_or_self(%Honchox.Session{id: id}), do: id
  defp id_or_self(value), do: value

  defp content_or_self(%Honchox.Message{content: content}), do: content
  defp content_or_self(value), do: value

  defp rename(opts, from, to) do
    case Map.pop(opts, from) do
      {nil, opts} -> opts
      {value, opts} -> Map.put(opts, to, value)
    end
  end
end
