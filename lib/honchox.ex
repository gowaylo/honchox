defmodule Honchox do
  @moduledoc """
  Req-based Elixir client for the Honcho v3 HTTP API.

  `Honchox` is the main entry point for interacting with the
  [Honcho](https://honcho.dev) API. It wraps [`Req`](https://hexdocs.pm/req)
  with built-in authentication, retry logic, and structured error handling.

  ## Creating a client

  Use `new/1` to build a client struct. The API key can be passed directly or
  read from the `HONCHO_API_KEY` environment variable:

      client = Honchox.new(api_key: "sk-...")

  The base URL defaults to `https://api.honcho.ai` and can be overridden via
  the `:base_url` option or the `HONCHO_URL` environment variable.

  ## Workspace-scoped resources

  Most resource endpoints (peers, sessions, conclusions) are scoped to a
  workspace. Instead of storing the workspace ID in the client, you pass it
  explicitly via the `:workspace_id` option on each call:

      Honchox.Peers.get_or_create(client, "alice", workspace_id: "my-workspace")

  ## Resource modules

    * `Honchox.Workspaces` — workspace lifecycle, search, queue status, dream scheduling
    * `Honchox.Peers` — peer lifecycle, chat, context, representation, cards
    * `Honchox.Sessions` — session lifecycle, messages, peers, context, files
    * `Honchox.Conclusions` — conclusion CRUD and semantic search
    * `Honchox.Observations` — backward-compatible aliases for conclusions

  ## Low-level HTTP

  The `get/3`, `post/3`, `put/3`, `patch/3`, `delete/3`, and `upload/4`
  functions are available for making direct API calls when the resource
  modules don't cover a specific endpoint.
  """

  @default_base_url "https://api.honcho.ai"
  @default_timeout 60_000
  @default_max_retries 2

  @typedoc "A configured Honcho API client."
  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          workspace_id: String.t() | nil,
          req: Req.Request.t(),
          timeout: pos_integer(),
          max_retries: non_neg_integer()
        }

  @typedoc "Options accepted by `new/1`."
  @type client_option ::
          {:api_key, String.t()}
          | {:base_url, String.t()}
          | {:timeout, pos_integer()}
          | {:max_retries, non_neg_integer()}

  defstruct [:api_key, :base_url, :workspace_id, :req, :timeout, :max_retries]

  @doc """
  Builds a new Honcho API client.

  Returns a `%Honchox{}` struct with a pre-configured `Req.Request` that
  carries authentication and transport defaults.

  ## Options

    * `:api_key` — Honcho API key. Falls back to the `HONCHO_API_KEY` env var.
      **Required.**
    * `:base_url` — API base URL. Falls back to `HONCHO_URL` env var, then
      `#{@default_base_url}`. (default: `"#{@default_base_url}"`)
    * `:timeout` — receive timeout in milliseconds (default: `#{@default_timeout}`)
    * `:max_retries` — max retries on transient failures (default: `#{@default_max_retries}`)

  Any additional keyword options are forwarded to `Req.new/1`.

  ## Examples

      client = Honchox.new(api_key: "sk-...")
      client.base_url
      #=> "https://api.honcho.ai"

      client = Honchox.new(api_key: "sk-...", base_url: "https://api.honcho.dev")
      client.base_url
      #=> "https://api.honcho.dev"

  """
  @spec new([client_option]) :: t()
  def new(opts \\ []) when is_list(opts) do
    api_key = required_config_value!(opts, :api_key, "HONCHO_API_KEY")
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
      workspace_id: nil,
      timeout: timeout,
      max_retries: max_retries,
      req: Req.new(req_opts)
    }
  end

  @doc """
  Sends a GET request to the given `path` with optional query `params`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec get(t(), String.t(), keyword()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def get(%__MODULE__{} = client, path, params \\ []) do
    request(client, :get, path, params: params)
  end

  @doc """
  Sends a POST request to the given `path` with a JSON `body`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec post(t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def post(%__MODULE__{} = client, path, body) do
    request(client, :post, path, json: body)
  end

  @doc """
  Sends a PUT request to the given `path` with a JSON `body`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec put(t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def put(%__MODULE__{} = client, path, body) do
    request(client, :put, path, json: body)
  end

  @doc """
  Sends a PATCH request to the given `path` with a JSON `body`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec patch(t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def patch(%__MODULE__{} = client, path, body) do
    request(client, :patch, path, json: body)
  end

  @doc """
  Sends a DELETE request to the given `path` with optional query `params`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec delete(t(), String.t(), keyword()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%__MODULE__{} = client, path, params \\ []) do
    request(client, :delete, path, params: params)
  end

  @doc """
  Sends a multipart upload (POST) to the given `path`.

  `fields` is a keyword list of form fields passed to Req's `:form_multipart`
  option. Any extra `opts` are merged into the Req request options.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec upload(t(), String.t(), keyword(), keyword()) :: {:ok, term()} | {:error, Honchox.Error.t()}
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
