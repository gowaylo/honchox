defmodule Honchox.Observations do
  @moduledoc """
  Backward-compatible observation wrappers over v3 conclusion endpoints.
  """

  def list(%Honchox{} = client, opts \\ []) do
    Honchox.Conclusions.list(client, opts)
  end

  def query(%Honchox{} = client, query, opts \\ []) do
    Honchox.Conclusions.query(client, query, opts)
  end

  def delete(%Honchox{} = client, observation_id) do
    Honchox.Conclusions.delete(client, observation_id)
  end
end
