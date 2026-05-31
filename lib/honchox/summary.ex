defmodule Honchox.Summary do
  @moduledoc """
  Public session summary converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          content: String.t() | nil,
          message_id: String.t() | nil,
          summary_type: String.t() | nil,
          created_at: term() | nil,
          token_count: integer() | nil
        }

  defstruct [:content, :message_id, :summary_type, :created_at, :token_count]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      content: opt(data, :content),
      message_id: opt(data, :message_id),
      summary_type: opt(data, :summary_type),
      created_at: opt(data, :created_at),
      token_count: opt(data, :token_count)
    }
  end
end
