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

  ## Resources

  Most resource endpoints are scoped to a workspace. The client stores a
  workspace ID from `:workspace_id`, `HONCHO_WORKSPACE_ID`, or `"default"` as
  client configuration and entry points return structs:

      {:ok, peer} = Honchox.peer(client, "alice")
      {:ok, response} = Honchox.Peer.chat(peer, "What was our last topic?")
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
      then `"default"`.
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
  Ensures the client's configured workspace exists.
  """
  @spec workspace(t(), keyword() | map()) ::
          {:ok, Honchox.Workspace.t()} | {:error, Honchox.Error.t()}
  def workspace(%Honchox.Client{} = client, opts \\ []) do
    with {:ok, data} <- Honchox.API.Workspaces.get_or_create(client, client.workspace_id, opts) do
      {:ok, Honchox.Workspace.from_api(client, data)}
    end
  end

  @doc """
  Returns queue status for the client's configured workspace.

  Accepts optional `:observer`, `:sender`, and `:session` filters as IDs or
  resource structs.
  """
  @spec queue_status(t(), keyword() | map()) ::
          {:ok, Honchox.QueueStatus.t()} | {:error, Honchox.Error.t()}
  def queue_status(%Honchox.Client{} = client, opts \\ []) do
    opts = normalize_queue_opts(opts)

    with {:ok, %Honchox.Workspace{}} <- workspace(client),
         {:ok, data} <- Honchox.API.Workspaces.queue_status(client, opts) do
      {:ok, Honchox.QueueStatus.from_api(data)}
    end
  end

  @doc """
  Manually schedules a dream for a peer representation.

  Dreams consolidate existing conclusions for an `(observer, observed)` peer
  pair. `observer` can be a peer struct or ID. Pass `:observed` to schedule a
  dream for what the observer knows about another peer; otherwise the observed
  peer defaults to the observer. Pass `:session` to scope the dream to a session.

  The API schedules work asynchronously; it does not wait for the dream to be
  processed.
  """
  @spec schedule_dream(t(), Honchox.Peer.t() | String.t(), keyword() | map()) ::
          :ok | {:error, Honchox.Error.t()}
  def schedule_dream(%Honchox.Client{} = client, observer, opts \\ []) do
    observer_id = peer_id(observer)

    opts =
      opts
      |> Honchox.API.Helpers.opts_to_map()
      |> Map.put(:observer_id, observer_id)
      |> Map.update(:observed, observer_id, &peer_id/1)
      |> Map.update(:session, nil, &session_id/1)
      |> rename(:observed, :observed_id)
      |> rename(:session, :session_id)

    with {:ok, %Honchox.Workspace{}} <- workspace(client),
         {:ok, _data} <- Honchox.API.Workspaces.schedule_dream(client, opts) do
      :ok
    end
  end

  @doc """
  Ensures the client's workspace and creates or returns a peer in it.
  """
  @spec peer(t(), String.t(), keyword() | map()) ::
          {:ok, Honchox.Peer.t()} | {:error, Honchox.Error.t()}
  def peer(%Honchox.Client{} = client, id, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- workspace(client),
         {:ok, data} <- Honchox.API.Peers.get_or_create(client, id, opts) do
      {:ok, Honchox.Peer.from_api(client, client.workspace_id, data)}
    end
  end

  @doc """
  Ensures the client's workspace and lists peers in it.
  """
  @spec peers(t(), keyword() | map()) ::
          {:ok, Honchox.Page.t(Honchox.Peer.t())} | {:error, Honchox.Error.t()}
  def peers(%Honchox.Client{} = client, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- workspace(client),
         {:ok, data} <- Honchox.API.Peers.list(client, opts) do
      {:ok, Honchox.Page.from_api(data, &Honchox.Peer.from_api(client, client.workspace_id, &1))}
    end
  end

  @doc """
  Ensures the client's workspace and creates or returns a session in it.
  """
  @spec session(t(), String.t(), keyword() | map()) ::
          {:ok, Honchox.Session.t()} | {:error, Honchox.Error.t()}
  def session(%Honchox.Client{} = client, id, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- workspace(client),
         {:ok, data} <- Honchox.API.Sessions.get_or_create(client, id, opts) do
      {:ok, Honchox.Session.from_api(client, client.workspace_id, data)}
    end
  end

  @doc """
  Ensures the client's workspace and lists sessions in it.
  """
  @spec sessions(t(), keyword() | map()) ::
          {:ok, Honchox.Page.t(Honchox.Session.t())} | {:error, Honchox.Error.t()}
  def sessions(%Honchox.Client{} = client, opts \\ []) do
    with {:ok, %Honchox.Workspace{}} <- workspace(client),
         {:ok, data} <- Honchox.API.Sessions.list(client, opts) do
      {:ok,
       Honchox.Page.from_api(data, &Honchox.Session.from_api(client, client.workspace_id, &1))}
    end
  end

  defp normalize_queue_opts(opts) do
    opts
    |> Honchox.API.Helpers.opts_to_map()
    |> Map.update(:observer, nil, &peer_id/1)
    |> Map.update(:sender, nil, &peer_id/1)
    |> Map.update(:session, nil, &session_id/1)
    |> rename(:observer, :observer_id)
    |> rename(:sender, :sender_id)
    |> rename(:session, :session_id)
  end

  defp peer_id(%Honchox.Peer{id: id}), do: id
  defp peer_id(value), do: value

  defp session_id(%Honchox.Session{id: id}), do: id
  defp session_id(value), do: value

  defp rename(opts, from, to) do
    case Map.pop(opts, from) do
      {nil, opts} -> opts
      {value, opts} -> Map.put(opts, to, value)
    end
  end
end
