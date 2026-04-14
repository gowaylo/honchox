defmodule Honchox do
  @moduledoc """
  Honcho API client for the v3 HTTP API.

  ## Examples

      iex> client = Honchox.new(api_key: "secret", workspace_id: "workspace-1")
      iex> client.workspace_id
      "workspace-1"
      iex> client.req.options[:auth]
      {:bearer, "secret"}
  """

  @default_base_url "https://api.honcho.ai"
  @default_timeout 60_000
  @default_max_retries 2

  defstruct [:api_key, :base_url, :workspace_id, :req, :timeout, :max_retries]

  @doc """
  Builds a client with a preconfigured `Req` request.
  """
  def new(opts \\ []) when is_list(opts) do
    api_key = required_config_value!(opts, :api_key, "HONCHO_API_KEY")
    workspace_id = required_config_value!(opts, :workspace_id, "HONCHO_WORKSPACE_ID")
    base_url = config_value(opts, :base_url, "HONCHO_URL", @default_base_url)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)

    req_opts =
      opts
      |> Keyword.drop([:api_key, :workspace_id, :base_url, :timeout, :max_retries])
      |> Keyword.put_new(:base_url, base_url)
      |> Keyword.put_new(:auth, {:bearer, api_key})
      |> Keyword.put_new(:receive_timeout, timeout)
      |> Keyword.put_new(:retry, :transient)
      |> Keyword.put_new(:max_retries, max_retries)

    %__MODULE__{
      api_key: api_key,
      base_url: base_url,
      workspace_id: workspace_id,
      timeout: timeout,
      max_retries: max_retries,
      req: Req.new(req_opts)
    }
  end

  @doc """
  Sends a GET request.
  """
  def get(%__MODULE__{} = client, path, params \\ []) do
    request(client, :get, path, params: params)
  end

  @doc """
  Sends a POST request with JSON body.
  """
  def post(%__MODULE__{} = client, path, body) do
    request(client, :post, path, json: body)
  end

  @doc """
  Sends a PUT request with JSON body.
  """
  def put(%__MODULE__{} = client, path, body) do
    request(client, :put, path, json: body)
  end

  @doc """
  Sends a PATCH request with JSON body.
  """
  def patch(%__MODULE__{} = client, path, body) do
    request(client, :patch, path, json: body)
  end

  @doc """
  Sends a DELETE request.
  """
  def delete(%__MODULE__{} = client, path, params \\ []) do
    request(client, :delete, path, params: params)
  end

  @doc """
  Sends a multipart upload request.
  """
  def upload(%__MODULE__{} = client, path, fields, opts \\ []) do
    request(client, :post, path, Keyword.merge(opts, form_multipart: fields))
  end

  defp request(%__MODULE__{} = client, method, path, request_opts) do
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

  defp config_value(opts, key, env_var, default \\ nil) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when not is_nil(value) -> value
      _ -> System.get_env(env_var) || default
    end
  end

  defp required_config_value!(opts, key, env_var) do
    value = config_value(opts, key, env_var)

    if is_nil(value) do
      raise ArgumentError, "missing required Honchox config: #{key}"
    end

    value
  end
end
