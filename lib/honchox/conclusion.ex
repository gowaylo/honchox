defmodule Honchox.Conclusion do
  @moduledoc """
  Public conclusion value converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          content: String.t() | nil,
          observer_id: String.t() | nil,
          observed_id: String.t() | nil,
          session_id: String.t() | nil,
          created_at: term() | nil
        }

  defstruct [:id, :content, :observer_id, :observed_id, :session_id, :created_at]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: opt(data, :id),
      content: opt(data, :content),
      observer_id: opt(data, :observer_id),
      observed_id: opt(data, :observed_id),
      session_id: opt(data, :session_id),
      created_at: opt(data, :created_at)
    }
  end
end
