defmodule Honchox.Message do
  @moduledoc """
  Public message value converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          content: String.t() | nil,
          peer_id: String.t() | nil,
          session_id: String.t() | nil,
          workspace_id: String.t() | nil,
          metadata: map() | nil,
          created_at: term() | nil,
          token_count: integer() | nil
        }

  defstruct [
    :id,
    :content,
    :peer_id,
    :session_id,
    :workspace_id,
    :metadata,
    :created_at,
    :token_count
  ]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: opt(data, :id),
      content: opt(data, :content),
      peer_id: opt(data, :peer_id),
      session_id: opt(data, :session_id),
      workspace_id: opt(data, :workspace_id),
      metadata: opt(data, :metadata),
      created_at: opt(data, :created_at),
      token_count: opt(data, :token_count)
    }
  end
end
