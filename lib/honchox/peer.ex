defmodule Honchox.Peer do
  @moduledoc """
  Public peer resource converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t(),
          client: Honchox.Client.t() | nil,
          metadata: map() | nil,
          configuration: map() | nil,
          created_at: term() | nil
        }

  defstruct [:id, :workspace_id, :client, :metadata, :configuration, :created_at]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(Honchox.Client.t() | nil, String.t(), map()) :: t()
  def from_api(client, workspace_id, data) when is_map(data) do
    %__MODULE__{
      id: opt(data, :id),
      workspace_id: workspace_id,
      client: client,
      metadata: opt(data, :metadata),
      configuration: opt(data, :configuration),
      created_at: opt(data, :created_at)
    }
  end
end
