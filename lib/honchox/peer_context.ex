defmodule Honchox.PeerContext do
  @moduledoc """
  Public peer context converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          peer_id: String.t() | nil,
          target_id: String.t() | nil,
          representation: String.t() | nil,
          peer_card: [String.t()] | nil
        }

  defstruct [:peer_id, :target_id, :representation, :peer_card]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      peer_id: opt(data, :peer_id),
      target_id: opt(data, :target_id),
      representation: opt(data, :representation),
      peer_card: opt(data, :peer_card)
    }
  end
end
