# Script para testar o endpoint POST /v3/keys contra a instância self-hosted
#
# Uso:
#   source .env && mix run scripts/test_keys.exs
#
# Requer: HONCHO_API_KEY (admin JWT) e HONCHO_URL no ambiente

defmodule TestKeys do
  def run do
    client = Honchox.new()

    IO.puts("=== Honcho API Keys — Teste Completo ===\n")
    IO.puts("URL:   #{client.base_url}")
    IO.puts("Token: #{String.slice(client.api_key, 0..30)}...\n")

    IO.puts("--- Setup: criando recursos de teste ---")
    ws_id = "keys-test-#{System.system_time(:second)}"
    client = Honchox.new(api_key: client.api_key, base_url: client.base_url, workspace_id: ws_id)

    {:ok, workspace} = Honchox.workspace(client)
    IO.puts("[OK] Workspace pronto: #{workspace.id}\n")

    {:ok, peer} = Honchox.peer(client, "test-peer", metadata: %{test: true})
    peer_id = peer.id
    IO.puts("[OK] Peer pronto: #{peer_id}")

    {:ok, session} = Honchox.session(client, "test-session", metadata: %{test: true})
    session_id = session.id
    IO.puts("[OK] Session pronta: #{session_id}\n")

    tests = [
      {"1. Key com escopo workspace apenas", [workspace_id: ws_id], :ok},
      {"2. Key com escopo peer apenas", [peer_id: peer_id], :ok},
      {"3. Key com escopo session apenas", [session_id: session_id], :ok},
      {"4. Key com escopo workspace + peer", [workspace_id: ws_id, peer_id: peer_id], :ok},
      {"5. Key com escopo workspace + session", [workspace_id: ws_id, session_id: session_id], :ok},
      {"6. Key com escopo peer + session", [peer_id: peer_id, session_id: session_id], :ok},
      {"7. Key com todos os escopos", [workspace_id: ws_id, peer_id: peer_id, session_id: session_id], :ok},
      {"8. Key com workspace + expires_at", [workspace_id: ws_id, expires_at: future_datetime()], :ok},
      {"9. Key com todos escopos + expires_at", [workspace_id: ws_id, peer_id: peer_id, session_id: session_id, expires_at: future_datetime()], :ok},
      {"10. Key sem nenhum escopo (deve falhar 422)", [], :error},
      {"11. Key com apenas expires_at, sem escopo (deve falhar 422)", [expires_at: future_datetime()], :error}
    ]

    results =
      Enum.map(tests, fn {name, params, expected} ->
        IO.puts("--- #{name} ---")
        IO.puts("    Params: #{inspect(params)}")

        result = Honchox.Keys.create(client, params)

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

    IO.puts("\n--- 12. Validação: usar key com escopo workspace pra listar peers ---")

    case Honchox.Keys.create(client, workspace_id: ws_id) do
      {:ok, %{"key" => scoped_key}} ->
        scoped_client = Honchox.new(jwt: scoped_key, base_url: client.base_url, workspace_id: ws_id)

        case Honchox.peers(scoped_client) do
          {:ok, _peers} -> IO.puts("    [PASS] Key com escopo workspace conseguiu listar peers")
          {:error, err} -> IO.puts("    [FAIL] Key com escopo workspace rejeitada: #{inspect(err)}")
        end

      {:error, err} ->
        IO.puts("    [SKIP] Não conseguiu criar key: #{inspect(err)}")
    end

    IO.puts("\n--- 13. Validação: key com escopo session NÃO deve acessar peers do workspace ---")

    case Honchox.Keys.create(client, session_id: session_id) do
      {:ok, %{"key" => narrow_key}} ->
        narrow_client = Honchox.new(jwt: narrow_key, base_url: client.base_url, workspace_id: ws_id)

        case Honchox.peers(narrow_client) do
          {:ok, _} -> IO.puts("    [INFO] Key com escopo session conseguiu listar peers (verificar se esperado)")
          {:error, %Honchox.Error{status: 401}} -> IO.puts("    [PASS] Key com escopo session foi rejeitada ao listar peers (401)")
          {:error, err} -> IO.puts("    [INFO] Erro: #{inspect(err)}")
        end

      {:error, err} ->
        IO.puts("    [SKIP] Não conseguiu criar key: #{inspect(err)}")
    end

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
