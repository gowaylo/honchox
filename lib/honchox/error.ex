defmodule Honchox.Error do
  @moduledoc """
  Structured error returned by Honchox helpers.
  """

  defexception [:message, :status, :code, :body, :kind]

  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.get(opts, :message, "honchox error")
    struct(__MODULE__, Keyword.put_new(opts, :message, message))
  end

  def http_error(status, body) do
    struct(__MODULE__,
      message: "request failed with status #{status}",
      status: status,
      code: status,
      body: body,
      kind: :http_error
    )
  end

  def transport_error(reason, message) do
    struct(__MODULE__,
      message: message,
      status: nil,
      code: reason,
      body: nil,
      kind: transport_kind(reason)
    )
  end

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
