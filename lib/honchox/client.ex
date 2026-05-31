defmodule Honchox.Client do
  @moduledoc """
  Immutable client configuration.

  `Honchox.Client` stores authentication, workspace, base URL, timeout, retry,
  and the preconfigured `Req.Request` used for HTTP calls. It is stateless:
  constructing a client does not create any Agent, ETS table, cache, or other
  process-global mutable state.
  """

  @default_base_url "https://api.honcho.dev"
  @default_workspace_id "default"
  @default_timeout 60_000
  @default_max_retries 2

  @typedoc "A configured Honcho API client."
  @type t :: %__MODULE__{
          api_key: String.t() | nil,
          jwt: String.t() | nil,
          base_url: String.t(),
          workspace_id: String.t(),
          req: Req.Request.t(),
          timeout: pos_integer(),
          max_retries: non_neg_integer()
        }

  @typedoc "Options accepted by `new/1`, including additional `Req.new/1` options."
  @type client_option ::
          {:api_key, String.t()}
          | {:jwt, String.t()}
          | {:base_url, String.t()}
          | {:workspace_id, String.t()}
          | {:timeout, pos_integer()}
          | {:max_retries, non_neg_integer()}
          | {atom(), term()}

  defstruct [:api_key, :jwt, :base_url, :workspace_id, :req, :timeout, :max_retries]

  @spec new([client_option]) :: t()
  def new(opts \\ []) when is_list(opts) do
    jwt = Keyword.get(opts, :jwt)
    api_key = if jwt, do: nil, else: required_config_value!(opts, :api_key, "HONCHO_API_KEY")
    token = jwt || api_key
    base_url = config_value(opts, :base_url, "HONCHO_URL", @default_base_url)
    workspace_id = config_value(opts, :workspace_id, "HONCHO_WORKSPACE_ID", @default_workspace_id)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)

    req_opts =
      opts
      |> Keyword.drop([:api_key, :jwt, :workspace_id, :base_url, :timeout, :max_retries])
      |> Keyword.put_new(:base_url, base_url)
      |> Keyword.put_new(:auth, {:bearer, token})
      |> Keyword.put_new(:receive_timeout, timeout)
      |> Keyword.put_new(:retry, :transient)
      |> Keyword.put_new(:max_retries, max_retries)

    %__MODULE__{
      api_key: api_key,
      jwt: jwt,
      base_url: base_url,
      workspace_id: workspace_id,
      timeout: timeout,
      max_retries: max_retries,
      req: Req.new(req_opts)
    }
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
