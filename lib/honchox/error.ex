defmodule Honchox.Error do
  @moduledoc """
  Structured error returned by all Honchox operations.

  Every function in the resource modules returns `{:ok, result}` on success or
  `{:error, %Honchox.Error{}}` on failure. The struct carries enough context
  to distinguish HTTP errors from transport-level problems and to inspect the
  raw response body when needed.

  ## Fields

    * `:message` — human-readable error description
    * `:status` — HTTP status code (`nil` for non-HTTP errors)
    * `:code` — machine-readable error code (HTTP status, transport reason, or
      exception module)
    * `:body` — raw response body (`nil` for non-HTTP errors)
    * `:kind` — error category (see "Error kinds" below)

  ## Error kinds

    * `:http_error` — the server returned a non-2xx status code
    * `:timeout` — the request timed out
    * `:transport` — a network-level error (connection refused, DNS failure, etc.)
    * `:request_error` — any other exception during the request
  """

  @typedoc "The category of error that occurred."
  @type error_kind :: :http_error | :timeout | :transport | :request_error

  @typedoc "A structured Honchox error."
  @type t :: %__MODULE__{
          message: String.t(),
          status: pos_integer() | nil,
          code: term(),
          body: term(),
          kind: error_kind()
        }

  defexception [:message, :status, :code, :body, :kind]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.get(opts, :message, "honchox error")
    struct(__MODULE__, Keyword.put_new(opts, :message, message))
  end

  @doc """
  Builds an HTTP error from a status code and response body.

  ## Examples

      iex> error = Honchox.Error.http_error(404, %{"detail" => "Not found"})
      iex> error.kind
      :http_error
      iex> error.status
      404

  """
  @spec http_error(pos_integer(), term()) :: t()
  def http_error(status, body) do
    struct(__MODULE__,
      message: "request failed with status #{status}",
      status: status,
      code: status,
      body: body,
      kind: :http_error
    )
  end

  @doc """
  Builds a transport-level error from a reason atom and message string.

  Timeout errors (reason `:timeout`) get `kind: :timeout`; all other reasons
  get `kind: :transport`.
  """
  @spec transport_error(atom(), String.t()) :: t()
  def transport_error(reason, message) do
    struct(__MODULE__,
      message: message,
      status: nil,
      code: reason,
      body: nil,
      kind: transport_kind(reason)
    )
  end

  @doc """
  Wraps an arbitrary exception as a `%Honchox.Error{}` with `kind: :request_error`.
  """
  @spec request_error(Exception.t()) :: t()
  def request_error(exception) when is_exception(exception) do
    struct(__MODULE__,
      message: Exception.message(exception),
      status: nil,
      code: exception.__struct__,
      body: nil,
      kind: :request_error
    )
  end

  defp transport_kind(:timeout), do: :timeout
  defp transport_kind(_reason), do: :transport
end
