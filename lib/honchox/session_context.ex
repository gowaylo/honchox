defmodule Honchox.SessionContext do
  @moduledoc """
  Public session context converted from Honcho API responses.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          messages: [Honchox.Message.t()],
          summary: Honchox.Summary.t() | nil,
          peer_representation: String.t() | nil,
          peer_card: [String.t()] | nil
        }

  defstruct [:session_id, :messages, :summary, :peer_representation, :peer_card]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(String.t(), map()) :: t()
  def from_api(session_id, data) when is_map(data) do
    %__MODULE__{
      session_id: session_id,
      messages: Enum.map(opt(data, :messages) || [], &Honchox.Message.from_api/1),
      summary: summary_from_api(opt(data, :summary)),
      peer_representation: opt(data, :peer_representation),
      peer_card: opt(data, :peer_card)
    }
  end

  defp summary_from_api(nil), do: nil
  defp summary_from_api(summary) when is_map(summary), do: Honchox.Summary.from_api(summary)
end
