defmodule Honchox.Page do
  @moduledoc """
  Public paginated response converted from Honcho API responses.
  """

  @type t(item) :: %__MODULE__{
          items: [item],
          total: integer() | nil,
          page: integer() | nil,
          size: integer() | nil,
          pages: integer() | nil
        }

  defstruct [:items, :total, :page, :size, :pages]

  import Honchox.API.Helpers, only: [opt: 2]

  @spec from_api(map(), (term() -> term())) :: t(term())
  def from_api(data, mapper \\ fn item -> item end)
      when is_map(data) and is_function(mapper, 1) do
    %__MODULE__{
      items: Enum.map(opt(data, :items) || [], mapper),
      total: opt(data, :total),
      page: opt(data, :page),
      size: opt(data, :size),
      pages: opt(data, :pages)
    }
  end
end
