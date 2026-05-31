defmodule Honchox.Workspace do
  @moduledoc """
  Public workspace resource converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          client: Honchox.Client.t() | nil,
          metadata: map() | nil,
          configuration: map() | nil,
          created_at: term() | nil
        }

  defstruct [:id, :client, :metadata, :configuration, :created_at]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(Honchox.Client.t() | nil, map()) :: t()
  def from_api(client \\ nil, data) when is_map(data) do
    %__MODULE__{
      id: opt(data, :id),
      client: client,
      metadata: opt(data, :metadata),
      configuration: opt(data, :configuration),
      created_at: opt(data, :created_at)
    }
  end
end
