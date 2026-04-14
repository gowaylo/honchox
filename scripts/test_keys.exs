# Script para testar o endpoint POST /v3/keys contra a instância self-hosted
#
# Uso:
#   source .env && mix run scripts/test_keys.exs
#
# Requer: HONCHO_API_KEY (admin JWT) e HONCHO_URL no ambiente

defmodule TestKeys do
  @base_path "/v3/keys"

  def run do
    client = Honchox.new()

    IO.puts("=== Honcho API Keys — Teste Completo ===\n")
    IO.puts("URL:   #{client.base_url}")
    IO.puts("Token: #{String.slice(client.api_key, 0..30)}...\n")

    # Primeiro garante que temos um workspace pra referenciar
    IO.puts("--- Setup: criando workspace de teste ---")
    ws_id = "keys-test-#{System.system_time(:second)}"

    case Honchox.Workspaces.get_or_create(client, ws_id) do
      {:ok, ws} ->
        IO.puts("[OK] Workspace criado: #{ws["id"]}\n")

      {:error, err} ->
        IO.puts("[ERRO] Falha ao criar workspace: #{inspect(err)}")
        System.halt(1)
    end

    # Cria um peer e session pra usar nos testes de escopo
    {:ok, peer} =
      Honchox.Peers.get_or_create(client, "test-peer",
        workspace_id: ws_id,
        metadata: %{test: true}
      )

    peer_id = peer["id"]
    IO.puts("[OK] Peer criado: #{peer_id}")

    {:ok, session} =
      Honchox.Sessions.get_or_create(client, "test-session",
        workspace_id: ws_id,
        metadata: %{test: true}
      )

    session_id = session["id"]
    IO.puts("[OK] Session criada: #{session_id}\n")

    # =====================================================================
    # Cenários de teste
    # =====================================================================

    tests = [
      # --- Cenários que devem funcionar (200) ---
      {
        "1. Key com escopo workspace apenas",
        [workspace_id: ws_id],
        :ok
      },
      {
        "2. Key com escopo peer apenas",
        [peer_id: peer_id],
        :ok
      },
      {
        "3. Key com escopo session apenas",
        [session_id: session_id],
        :ok
      },
      {
        "4. Key com escopo workspace + peer",
        [workspace_id: ws_id, peer_id: peer_id],
        :ok
      },
      {
        "5. Key com escopo workspace + session",
        [workspace_id: ws_id, session_id: session_id],
        :ok
      },
      {
        "6. Key com escopo peer + session",
        [peer_id: peer_id, session_id: session_id],
        :ok
      },
      {
        "7. Key com todos os escopos (workspace + peer + session)",
        [workspace_id: ws_id, peer_id: peer_id, session_id: session_id],
        :ok
      },
      {
        "8. Key com workspace + expires_at (futuro)",
        [workspace_id: ws_id, expires_at: future_datetime()],
        :ok
      },
      {
        "9. Key com todos escopos + expires_at",
        [
          workspace_id: ws_id,
          peer_id: peer_id,
          session_id: session_id,
          expires_at: future_datetime()
        ],
        :ok
      },

      # --- Cenários que devem falhar (422 — sem escopo) ---
      {
        "10. Key sem nenhum escopo (deve falhar 422)",
        [],
        :error
      },
      {
        "11. Key com apenas expires_at, sem escopo (deve falhar 422)",
        [expires_at: future_datetime()],
        :error
      }
    ]

    results =
      Enum.map(tests, fn {name, params, expected} ->
        IO.puts("--- #{name} ---")
        IO.puts("    Params: #{inspect(params)}")

        result = create_key(client, params)

        case {result, expected} do
          {{:ok, %{"key" => jwt}}, :ok} ->
            IO.puts("    [PASS] Key criada: #{String.slice(jwt, 0..40)}...")
            decode_and_print_jwt(jwt)
            :pass

          {{:error, %Honchox.Error{status: status}}, :error} ->
            IO.puts("    [PASS] Erro esperado — HTTP #{status}")
            :pass

          {{:ok, body}, :error} ->
            IO.puts("    [FAIL] Esperava erro, mas recebeu sucesso: #{inspect(body)}")
            :fail

          {{:error, err}, :ok} ->
            IO.puts("    [FAIL] Esperava sucesso, mas recebeu erro: #{inspect(err)}")
            :fail

          {other, _} ->
            IO.puts("    [FAIL] Resposta inesperada: #{inspect(other)}")
            :fail
        end
      end)

    # =====================================================================
    # Teste extra: usar uma key gerada pra fazer uma chamada autenticada
    # =====================================================================

    IO.puts("\n--- 12. Validação: usar key com escopo workspace pra listar peers ---")

    case create_key(client, workspace_id: ws_id) do
      {:ok, %{"key" => scoped_key}} ->
        scoped_client = Honchox.new(api_key: scoped_key, base_url: client.base_url)

        case Honchox.Peers.list(scoped_client, workspace_id: ws_id) do
          {:ok, _peers} ->
            IO.puts("    [PASS] Key com escopo workspace conseguiu listar peers")

          {:error, err} ->
            IO.puts("    [FAIL] Key com escopo workspace rejeitada: #{inspect(err)}")
        end

      {:error, err} ->
        IO.puts("    [SKIP] Não conseguiu criar key: #{inspect(err)}")
    end

    IO.puts("\n--- 13. Validação: key com escopo session NÃO deve acessar outro workspace ---")

    case create_key(client, session_id: session_id) do
      {:ok, %{"key" => narrow_key}} ->
        narrow_client = Honchox.new(api_key: narrow_key, base_url: client.base_url)

        case Honchox.Workspaces.list(narrow_client) do
          {:ok, _} ->
            IO.puts(
              "    [INFO] Key com escopo session conseguiu listar workspaces (verificar se esperado)"
            )

          {:error, %Honchox.Error{status: 401}} ->
            IO.puts("    [PASS] Key com escopo session foi rejeitada ao listar workspaces (401)")

          {:error, err} ->
            IO.puts("    [INFO] Erro: #{inspect(err)}")
        end

      {:error, err} ->
        IO.puts("    [SKIP] Não conseguiu criar key: #{inspect(err)}")
    end

    # =====================================================================
    # Resumo
    # =====================================================================

    pass_count = Enum.count(results, &(&1 == :pass))
    fail_count = Enum.count(results, &(&1 == :fail))

    IO.puts("\n=== Resumo ===")
    IO.puts("Total: #{length(results)} | Pass: #{pass_count} | Fail: #{fail_count}")

    if fail_count > 0 do
      IO.puts("\n⚠  Alguns testes falharam!")
      System.halt(1)
    else
      IO.puts("\nTodos os testes passaram.")
    end

    # Cleanup
    IO.puts("\n--- Cleanup: removendo workspace de teste ---")

    case Honchox.Workspaces.delete(client, ws_id) do
      {:ok, _} -> IO.puts("[OK] Workspace #{ws_id} removido")
      {:error, err} -> IO.puts("[WARN] Falha ao remover workspace: #{inspect(err)}")
    end
  end

  # Faz POST /v3/keys com query params
  defp create_key(client, params) do
    query =
      params
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn
        {:expires_at, %DateTime{} = dt} -> {"expires_at", DateTime.to_iso8601(dt)}
        {k, v} -> {to_string(k), to_string(v)}
      end)

    path =
      case query do
        [] -> @base_path
        _ -> "#{@base_path}?#{URI.encode_query(query)}"
      end

    # POST sem body — o endpoint espera query params, não JSON
    Req.request(client.req, method: :post, url: path)
    |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, Honchox.Error.http_error(status, body)}
  end

  defp handle_response({:error, exception}) do
    {:error, %Honchox.Error{message: inspect(exception), status: nil, kind: :transport}}
  end

  defp future_datetime do
    DateTime.utc_now() |> DateTime.add(3600 * 24 * 30, :second)
  end

  defp decode_and_print_jwt(jwt) do
    case String.split(jwt, ".") do
      [_header, payload, _sig] ->
        case Base.url_decode64(payload, padding: false) do
          {:ok, json} ->
            case Jason.decode(json) do
              {:ok, claims} -> IO.puts("    Claims: #{inspect(claims)}")
              _ -> IO.puts("    (não conseguiu parsear claims)")
            end

          _ ->
            IO.puts("    (não conseguiu decodar payload)")
        end

      _ ->
        IO.puts("    (JWT com formato inesperado)")
    end
  end
end

TestKeys.run()
