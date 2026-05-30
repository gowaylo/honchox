defmodule Honchox.HTTP do
  @moduledoc """
  Stateless HTTP helpers for `Honchox.Client`.

  This module wraps the configured `Req.Request` in a client and normalizes
  successful responses and errors into the public Honchox return shape.
  """

  alias Honchox.Client

  @spec get(Client.t(), String.t(), keyword()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def get(%Client{} = client, path, params \\ []) do
    request(client, :get, path, params: params)
  end

  @spec post(Client.t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def post(%Client{} = client, path, body) do
    request(client, :post, path, json: body)
  end

  @spec put(Client.t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def put(%Client{} = client, path, body) do
    request(client, :put, path, json: body)
  end

  @spec patch(Client.t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def patch(%Client{} = client, path, body) do
    request(client, :patch, path, json: body)
  end

  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Client{} = client, path, params \\ []) do
    request(client, :delete, path, params: params)
  end

  @spec upload(Client.t(), String.t(), keyword(), keyword()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def upload(%Client{} = client, path, fields, opts \\ []) do
    request(client, :post, path, Keyword.merge(opts, form_multipart: fields))
  end

  defp request(%Client{} = client, method, path, request_opts) do
    case Req.request(
           client.req,
           Keyword.put(request_opts, :method, method) |> Keyword.put(:url, path)
         ) do
      {:ok, %Req.Response{} = response} ->
        handle_response(response)

      {:error, exception} ->
        {:error, to_error(exception)}
    end
  end

  defp handle_response(%Req.Response{status: status, body: body}) when status in 200..299 do
    case {status, body} do
      {204, ""} -> {:ok, nil}
      {204, nil} -> {:ok, nil}
      _ -> {:ok, body}
    end
  end

  defp handle_response(%Req.Response{status: status, body: body}) do
    {:error, Honchox.Error.http_error(status, body)}
  end

  defp to_error(%Req.TransportError{reason: reason} = exception) do
    Honchox.Error.transport_error(reason, Exception.message(exception))
  end

  defp to_error(%Req.HTTPError{} = exception) do
    %Honchox.Error{
      message: Exception.message(exception),
      status: nil,
      code: exception.reason,
      body: nil,
      kind: :http_error
    }
  end

  defp to_error(exception) do
    Honchox.Error.request_error(exception)
  end
end
