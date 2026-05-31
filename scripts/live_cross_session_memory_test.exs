# Live cross-session memory/context test against Honcho's default API base URL.
#
# Scenario:
#   1. A user introduces themself, their profession, and future plans.
#   2. The same user discusses a technical sink/plumbing issue.
#   3. A final session asks for a 6-month preparation plan for one future goal.
#
# The test verifies that an application using Honchox can retrieve relevant
# context from prior sessions before composing the final answer.
#
# Usage:
#   env -u HONCHO_URL mix run scripts/live_cross_session_memory_test.exs
#
# Requires:
#   HONCHO_API_KEY

System.delete_env("HONCHO_URL")

defmodule LiveCrossSessionMemoryTest do
  @queries [
    "future plans machine learning product manager six month preparation plan",
    "profession backend engineer product management AI startup",
    "sink plumbing issue leaking p-trap faucet aerator"
  ]

  def run do
    suffix = "#{DateTime.utc_now() |> DateTime.to_unix()}-#{System.unique_integer([:positive])}"
    workspace_id = "honchox-live-memory-#{suffix}"

    client = Honchox.new(workspace_id: workspace_id, timeout: 20_000, max_retries: 0)

    IO.puts("=== Honchox live cross-session memory test ===")
    IO.puts("Base URL: #{client.base_url}")
    IO.puts("Workspace: #{workspace_id}")
    IO.puts("HONCHO_URL env after cleanup: #{inspect(System.get_env("HONCHO_URL"))}")
    IO.puts("API key present: #{not is_nil(client.api_key)}")
    IO.puts("")

    with {:ok, _workspace} <- Honchox.workspace(client, metadata: %{test: "cross_session_memory"}),
         {:ok, user} <- Honchox.peer(client, "usuario", metadata: %{role: "user"}),
         {:ok, agent} <- Honchox.peer(client, "agente", metadata: %{role: "assistant"}),
         :ok <- seed_sessions(client, user, agent),
         {:ok, final_session} <- final_session(client, user, agent),
         :ok <- evaluate_context(user, final_session) do
      IO.puts(
        "\nPASS: relevant prior-session context was retrievable for the final planning request."
      )
    else
      {:error, error} ->
        IO.puts("\nFAIL: #{inspect(error)}")
        System.halt(1)
    end
  end

  defp seed_sessions(client, user, agent) do
    sessions = [
      {"01-apresentacao", %{topic: "profile_and_future_plans"},
       [
         Honchox.Peer.message(
           user,
           "Oi, eu sou o Rafael. Trabalho como engenheiro de backend em Elixir numa fintech."
         ),
         Honchox.Peer.message(
           agent,
           "Prazer, Rafael. Quais planos voce tem para os proximos anos?"
         ),
         Honchox.Peer.message(
           user,
           "Quero migrar para Product Manager de produtos de IA e, no futuro, liderar uma startup de agentes inteligentes."
         ),
         Honchox.Peer.message(
           agent,
           "Entendi: backend Elixir hoje, transicao planejada para PM de produtos de IA e empreendedorismo em agentes inteligentes."
         )
       ]},
      {"02-problema-pia", %{topic: "sink_plumbing_issue"},
       [
         Honchox.Peer.message(
           user,
           "Minha pia da cozinha esta vazando embaixo, perto do sifao, e a agua acumula no armario."
         ),
         Honchox.Peer.message(
           agent,
           "Parece um problema no p-trap/sifao ou na vedacao. Voce ja apertou as conexoes?"
         ),
         Honchox.Peer.message(
           user,
           "Apertei o sifao e limpei o arejador da torneira; o vazamento diminuiu, mas ainda pinga quando a cuba enche."
         ),
         Honchox.Peer.message(
           agent,
           "O proximo passo seria trocar a arruela ou vedacao do sifao e testar com a cuba cheia."
         )
       ]}
    ]

    Enum.reduce_while(sessions, :ok, fn {session_id, metadata, messages}, :ok ->
      case add_session(client, user, agent, session_id, metadata, messages) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp add_session(client, user, agent, session_id, metadata, messages) do
    with {:ok, session} <- Honchox.session(client, session_id, metadata: metadata),
         :ok <- Honchox.Session.add_peers(session, [user, agent]),
         {:ok, _messages} <- Honchox.Session.add_messages(session, messages) do
      IO.puts("[OK] seeded #{session_id} (#{length(messages)} messages)")
      :ok
    end
  end

  defp final_session(client, user, agent) do
    with {:ok, session} <-
           Honchox.session(client, "03-plano-6-meses", metadata: %{topic: "future_goal_plan"}),
         :ok <- Honchox.Session.add_peers(session, [user, agent]),
         {:ok, _messages} <-
           Honchox.Session.add_messages(session, [
             Honchox.Peer.message(
               user,
               "Pode criar um plano de 6 meses para eu me preparar para um dos meus planos de futuro?"
             )
           ]) do
      IO.puts("[OK] seeded 03-plano-6-meses (planning request)")
      {:ok, session}
    end
  end

  defp evaluate_context(user, final_session) do
    IO.puts("\n=== Retrieved context for application prompt assembly ===")

    results =
      Enum.map(@queries, fn query ->
        {:ok, messages} = Honchox.Peer.search(user, query, target: user, limit: 10)

        {:ok, context} =
          Honchox.Peer.context(user, target: user, session: final_session, search_query: query)

        print_result(query, messages, context)
        {query, messages, context}
      end)

    combined_text =
      results
      |> Enum.flat_map(fn {_query, messages, context} ->
        Enum.map(messages, & &1.content) ++ [context.representation]
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")
      |> String.downcase()

    required = [
      "rafael",
      "engenheiro de backend",
      "product manager",
      "ia",
      "startup",
      "pia",
      "sifao"
    ]

    missing = Enum.reject(required, &String.contains?(combined_text, &1))

    if missing == [] do
      IO.puts("\nAll expected memory anchors found: #{inspect(required)}")
      :ok
    else
      {:error, "missing expected memory anchors: #{inspect(missing)}"}
    end
  rescue
    match_error in MatchError -> {:error, match_error.term}
  end

  defp print_result(query, messages, context) do
    IO.puts("\nQuery: #{query}")
    IO.puts("Search messages: #{inspect(Enum.map(messages, & &1.content))}")
    IO.puts("Peer representation: #{inspect(context.representation)}")
    IO.puts("Peer card: #{inspect(context.peer_card)}")
  end
end

LiveCrossSessionMemoryTest.run()
