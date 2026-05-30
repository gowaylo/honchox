defmodule Honchox.Observations do
  @moduledoc """
  Backward-compatible wrappers over the renamed conclusion endpoints.

  The Honcho v3 API renamed "observations" to "conclusions". This module
  provides the old function names so existing code continues to work.

  > #### Deprecation notice {: .warning}
  >
  > This module is deprecated. Use `Honchox.Conclusions` instead.
  > It will be removed in a future major release.
  """
  @moduledoc deprecated: "Use Honchox.Conclusions instead"

  @doc """
  Lists conclusions (formerly observations).

  Delegates to `Honchox.Conclusions.list/2`. See that function for options.
  """
  @doc deprecated: "Use Honchox.Conclusions.list/2 instead"
  @spec list(Honchox.Client.t(), keyword() | map()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def list(%Honchox.Client{} = client, opts \\ []) do
    Honchox.Conclusions.list(client, opts)
  end

  @doc """
  Queries conclusions (formerly observations) with semantic search.

  Delegates to `Honchox.Conclusions.query/3`. See that function for options.
  """
  @doc deprecated: "Use Honchox.Conclusions.query/3 instead"
  @spec query(Honchox.Client.t(), String.t(), keyword() | map()) ::
          {:ok, map()} | {:error, Honchox.Error.t()}
  def query(%Honchox.Client{} = client, query, opts \\ []) do
    Honchox.Conclusions.query(client, query, opts)
  end

  @doc """
  Deletes a conclusion (formerly observation) by ID.

  Delegates to `Honchox.Conclusions.delete/3`. See that function for options.
  """
  @doc deprecated: "Use Honchox.Conclusions.delete/3 instead"
  @spec delete(Honchox.Client.t(), String.t(), keyword() | map()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Honchox.Client{} = client, observation_id, opts \\ []) do
    Honchox.Conclusions.delete(client, observation_id, opts)
  end
end
