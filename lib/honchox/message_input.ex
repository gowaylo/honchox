defmodule Honchox.MessageInput do
  @moduledoc """
  Public message input value built for peer messages.
  """

  @type t :: %__MODULE__{
          peer_id: String.t() | nil,
          content: String.t(),
          metadata: map() | nil,
          configuration: map() | nil,
          created_at: term() | nil
        }

  defstruct [:peer_id, :content, :metadata, :configuration, :created_at]
end
