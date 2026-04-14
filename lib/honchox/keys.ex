defmodule Honchox.Keys do
  @moduledoc """
  Admin endpoints for creating scoped JWTs.

  These endpoints mint short-lived bearer tokens that can be constrained to a
  workspace, peer, or session. They are useful when an admin client needs to
  delegate limited access to another client without exposing the original API
  key.

  ## Examples

      admin = Honchox.new(api_key: "sk-admin")

      {:ok, %{"key" => jwt}} =
        Honchox.Keys.create(admin,
          workspace_id: "workspace-1",
          expires_in: {1, :hour}
        )

      {:ok, scoped_client} =
        Honchox.Keys.create_client(admin,
          workspace_id: "workspace-1",
          peer_id: "alice"
        )

  """

  @base_path "/v3/keys"

  @doc """
  Creates a scoped JWT using the admin `client`.

  The request is sent as a `POST` to `#{@base_path}` with query parameters and
  no JSON body.

  ## Options

    * `:workspace_id` — scope the JWT to a workspace
    * `:peer_id` — scope the JWT to a peer
    * `:session_id` — scope the JWT to a session
    * `:expires_in` — relative expiration as `{value, unit}`
    * `:expires_at` — absolute expiration as a `DateTime` or ISO 8601 string

  Supported units for `:expires_in` are `:second`, `:seconds`, `:minute`,
  `:minutes`, `:hour`, `:hours`, `:day`, and `:days`.

  ## Examples

      Honchox.Keys.create(client, workspace_id: "workspace-1")

      Honchox.Keys.create(client,
        workspace_id: "workspace-1",
        peer_id: "alice",
        expires_in: {1, :hour}
      )

  """
  @spec create(Honchox.t(), keyword()) :: {:ok, map()} | {:error, Honchox.Error.t()}
  def create(%Honchox{} = client, opts \\ []) when is_list(opts) do
    path = with_query(@base_path, query_params(opts))

    case Req.request(client.req, method: :post, url: path) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, Honchox.Error.http_error(status, body)}

      {:error, exception} ->
        {:error, Honchox.Error.request_error(exception)}
    end
  end

  @doc """
  Creates a scoped JWT and returns a new `Honchox` client authenticated with it.

  The returned client inherits `:base_url`, `:timeout`, and `:max_retries` from
  the admin client.

  ## Examples

      {:ok, scoped_client} =
        Honchox.Keys.create_client(admin_client,
          workspace_id: "workspace-1",
          expires_in: {1, :hour}
        )

  """
  @spec create_client(Honchox.t(), keyword()) :: {:ok, Honchox.t()} | {:error, Honchox.Error.t()}
  def create_client(%Honchox{} = client, opts \\ []) when is_list(opts) do
    with {:ok, %{"key" => jwt}} <- create(client, opts) do
      {:ok,
       Honchox.new(
         jwt: jwt,
         base_url: client.base_url,
         timeout: client.timeout,
         max_retries: client.max_retries
       )}
    end
  end

  defp query_params(opts) do
    opts
    |> Keyword.take([:workspace_id, :peer_id, :session_id])
    |> maybe_put_expiration(resolve_expiration(opts))
  end

  defp maybe_put_expiration(params, nil), do: params
  defp maybe_put_expiration(params, expires_at), do: Keyword.put(params, :expires_at, expires_at)

  defp resolve_expiration(opts) do
    cond do
      expires_at = Keyword.get(opts, :expires_at) ->
        format_datetime(expires_at)

      expires_in = Keyword.get(opts, :expires_in) ->
        case expires_in do
          {value, unit} ->
            DateTime.utc_now()
            |> DateTime.add(to_seconds(value, unit), :second)
            |> format_datetime()
        end

      true ->
        nil
    end
  end

  defp to_seconds(value, unit) when is_integer(value) and value >= 0 do
    case unit do
      :second -> value
      :seconds -> value
      :minute -> value * 60
      :minutes -> value * 60
      :hour -> value * 3_600
      :hours -> value * 3_600
      :day -> value * 86_400
      :days -> value * 86_400
    end
  end

  defp format_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp format_datetime(value) when is_binary(value) do
    value
    |> DateTime.from_iso8601()
    |> case do
      {:ok, datetime, _offset} -> DateTime.to_iso8601(datetime)
      {:error, reason} -> raise ArgumentError, "invalid expires_at: #{inspect(reason)}"
    end
  end

  defp with_query(path, query) do
    case query do
      [] -> path
      _ -> "#{path}?#{URI.encode_query(query)}"
    end
  end
end
