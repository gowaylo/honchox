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

  The base URL defaults to `https://api.honcho.dev` and can be overridden via
  the `:base_url` option or the `HONCHO_URL` environment variable.

  ## Workspace-scoped resources

  Most resource endpoints (peers, sessions, conclusions) are scoped to a
  workspace. The client stores a workspace ID from `:workspace_id`,
  `HONCHO_WORKSPACE_ID`, or `"default"` as client configuration. Current
  resource modules still require `:workspace_id` on each resource call until
  client-level workspace defaults are wired into resources:

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

  @default_base_url "https://api.honcho.dev"
  @default_timeout 60_000
  @default_max_retries 2

  @typedoc "A configured Honcho API client."
  @type t :: Honchox.Client.t()

  @typedoc "Options accepted by `new/1`, including additional `Req.new/1` options."
  @type client_option ::
          {:api_key, String.t()}
          | {:jwt, String.t()}
          | {:base_url, String.t()}
          | {:workspace_id, String.t()}
          | {:timeout, pos_integer()}
          | {:max_retries, non_neg_integer()}
          | {atom(), term()}

  @doc """
  Builds a new Honcho API client.

  Returns a `%Honchox.Client{}` struct with a pre-configured `Req.Request` that
  carries authentication and transport defaults.

  ## Options

    * `:api_key` — Honcho API key. Falls back to the `HONCHO_API_KEY` env var
      when `:jwt` is not provided.
    * `:jwt` — scoped JWT bearer token. When provided, it is used for auth
      instead of `:api_key`.
    * `:base_url` — API base URL. Falls back to `HONCHO_URL` env var, then
      `#{@default_base_url}`. (default: `"#{@default_base_url}"`)
    * `:workspace_id` — client workspace ID. Falls back to `HONCHO_WORKSPACE_ID`,
      then `"default"`. Resource calls still require `:workspace_id` today.
    * `:timeout` — receive timeout in milliseconds (default: `#{@default_timeout}`)
    * `:max_retries` — max retries on transient failures (default: `#{@default_max_retries}`)

  Any additional keyword options are forwarded to `Req.new/1`.

  ## Examples

      client = Honchox.new(api_key: "sk-...")
      client.base_url
      #=> "https://api.honcho.dev"

      client = Honchox.new(api_key: "sk-...", base_url: "https://api.honcho.dev")
      client.base_url
      #=> "https://api.honcho.dev"

  """
  @spec new([client_option]) :: t()
  def new(opts \\ []) when is_list(opts) do
    Honchox.Client.new(opts)
  end

  @doc """
  Sends a GET request to the given `path` with optional query `params`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec get(t(), String.t(), keyword()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def get(%Honchox.Client{} = client, path, params \\ []) do
    Honchox.HTTP.get(client, path, params)
  end

  @doc """
  Sends a POST request to the given `path` with a JSON `body`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec post(t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def post(%Honchox.Client{} = client, path, body) do
    Honchox.HTTP.post(client, path, body)
  end

  @doc """
  Sends a PUT request to the given `path` with a JSON `body`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec put(t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def put(%Honchox.Client{} = client, path, body) do
    Honchox.HTTP.put(client, path, body)
  end

  @doc """
  Sends a PATCH request to the given `path` with a JSON `body`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec patch(t(), String.t(), term()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def patch(%Honchox.Client{} = client, path, body) do
    Honchox.HTTP.patch(client, path, body)
  end

  @doc """
  Sends a DELETE request to the given `path` with optional query `params`.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec delete(t(), String.t(), keyword()) :: {:ok, term()} | {:error, Honchox.Error.t()}
  def delete(%Honchox.Client{} = client, path, params \\ []) do
    Honchox.HTTP.delete(client, path, params)
  end

  @doc """
  Sends a multipart upload (POST) to the given `path`.

  `fields` is a keyword list of form fields passed to Req's `:form_multipart`
  option. Any extra `opts` are merged into the Req request options.

  Returns `{:ok, body}` on success or `{:error, %Honchox.Error{}}` on failure.
  """
  @spec upload(t(), String.t(), keyword(), keyword()) ::
          {:ok, term()} | {:error, Honchox.Error.t()}
  def upload(%Honchox.Client{} = client, path, fields, opts \\ []) do
    Honchox.HTTP.upload(client, path, fields, opts)
  end
end
