# Live cross-session memory/context test against Honcho's default API base URL.
#
# Scenario:
#   1. A user introduces themself, their profession, and several future plans.
#   2. The same user discusses a technical sink/plumbing issue.
#   3. A final session asks for a 6-month preparation plan for one specific
#      future goal from session 1.
#
# The test verifies both raw semantic recall and representation/conclusion-based
# recall. It adds enough message content to cross Honcho's representation batching
# threshold and configures the assistant to observe the user before messages are
# written.
#
# Usage:
#   env -u HONCHO_URL mix run scripts/live_cross_session_memory_test.exs
#
# Requires:
#   HONCHO_API_KEY

System.delete_env("HONCHO_URL")

defmodule LiveCrossSessionMemoryTest do
  @final_query "plano de 6 meses para migrar especificamente para Product Manager de produtos de IA"
  @required_goal_anchors ["rafael", "engenheiro de backend", "product manager", "ia"]
  @non_goal_anchor "sifao"

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

    with {:ok, _workspace} <-
           Honchox.workspace(client,
             metadata: %{test: "cross_session_memory", version: "representation_observer"}
           ),
         {:ok, user} <-
           Honchox.peer(client, "usuario",
             metadata: %{role: "user"},
             configuration: %{observe_me: true}
           ),
         {:ok, agent} <-
           Honchox.peer(client, "agente",
             metadata: %{role: "assistant"},
             configuration: %{observe_me: false}
           ),
         :ok <- seed_sessions(client, user, agent),
         {:ok, final_session} <- final_session(client, user, agent),
         :ok <- wait_for_scoped_queue(final_session, agent, user),
         :ok <- evaluate_context(agent, user, final_session) do
      IO.puts("\nPASS: prior-session context for the specific future goal was retrievable.")
    else
      {:error, error} ->
        IO.puts("\nFAIL: #{inspect(error)}")
        System.halt(1)
    end
  end

  defp seed_sessions(client, user, agent) do
    sessions = [
      {"01-apresentacao", %{topic: "profile_and_future_plans"}, profile_messages(user, agent)},
      {"02-problema-pia", %{topic: "sink_plumbing_issue"}, sink_messages(user, agent)}
    ]

    Enum.reduce_while(sessions, :ok, fn {session_id, metadata, messages}, :ok ->
      case add_session(client, user, agent, session_id, metadata, messages) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp add_session(client, user, agent, session_id, metadata, messages) do
    with {:ok, session} <-
           Honchox.session(client, session_id,
             metadata: metadata,
             configuration: %{reasoning: %{enabled: true}, peer_card: %{use: true, create: true}}
           ),
         :ok <- Honchox.Session.add_peers(session, [user, agent]),
         :ok <- Honchox.Session.set_peer_configuration(session, user, %{observe_me: true}),
         :ok <- Honchox.Session.set_peer_configuration(session, agent, %{observe_others: true}),
         {:ok, _messages} <- Honchox.Session.add_messages(session, messages) do
      IO.puts("[OK] seeded #{session_id} (#{length(messages)} messages)")
      :ok
    end
  end

  defp profile_messages(user, agent) do
    [
      # -- Opening --
      Honchox.Peer.message(
        user,
        "Oi! Meu nome é Rafael, prazer. Sou engenheiro de backend aqui no Brasil, trabalho com Elixir numa fintech. No dia a dia eu desenho APIs, pipelines de dados, integrações com bancos e serviços de mensageria. Gosto bastante da parte de sistemas distribuídos, observabilidade e testes automatizados."
      ),
      Honchox.Peer.message(
        agent,
        "Prazer, Rafael! Engenharia de backend em Elixir é um baita diferencial. Me conta um pouco mais sobre o que você faz: você atua mais na arquitetura dos sistemas, na implementação das features ou nas duas coisas?"
      ),
      Honchox.Peer.message(
        user,
        "As duas coisas, na verdade. A gente tem uma cultura de você constrói, você opera. Então eu participo desde a definição da arquitetura, decisões sobre modelagem de dados, escolha de tecnologias, até a implementação das features, revisão de código e on-call. Isso me deu uma visão bem completa do ciclo de vida do produto."
      ),
      Honchox.Peer.message(
        agent,
        "Isso é ótimo. Ter vivido o ciclo completo te coloca numa posição privilegiada. Aproveitando, o que te trouxe aqui? Tem algum plano ou objetivo de carreira em mente?"
      ),

      # -- Primary plan: Product Manager for AI products --
      Honchox.Peer.message(
        user,
        "Tenho sim. Meu plano principal é migrar para Product Manager de produtos de IA nos próximos anos. Eu quero usar minha bagagem técnica para liderar a parte de discovery de produto, priorização de roadmap, definição de métricas de sucesso, experimentação, entrevistas com usuários e estratégia de produto. Meu foco seria em soluções com agentes inteligentes."
      ),
      Honchox.Peer.message(
        agent,
        "Interessante! Você já tem uma base técnica sólida, o que é raro em Product Managers. Como você imagina essa transição — pretende fazer algum curso, montar portfólio, pegar projetos paralelos? E que tipo de produto de IA você imagina?"
      ),
      Honchox.Peer.message(
        user,
        "Penso em estudar product discovery a fundo, gestão de roadmap, métricas de produto e pesquisa com usuários. Do lado técnico preciso me aprofundar em LLMs, avaliação de agentes, engenharia de prompt, ética e go-to-market. Quero montar um portfólio com um produto de IA real, mesmo que pequeno, e praticar entrevistas de PM. O ideal seria conseguir uma posição como Product Manager de produtos de IA em uma empresa que já tenha times internacionais."
      ),
      Honchox.Peer.message(
        agent,
        "Faz sentido. Você mencionou times internacionais — o seu inglês já está num nível confortável pra trabalhar com equipes de fora?"
      ),
      Honchox.Peer.message(
        user,
        "Ainda não. Meu inglês é intermediário, consigo ler e escrever bem, mas a conversação trava um pouco. Melhorar o inglês está na minha lista de prioridades, especialmente se eu quiser vagas de Product Manager de IA em empresas globais. Acho que é um pré-requisito."
      ),
      Honchox.Peer.message(
        agent,
        "Com certeza. E você tem algum prazo em mente pra essa transição? Ou está mais num momento de explorar e construir a base?"
      ),
      Honchox.Peer.message(
        user,
        "Estou pensando em fazer essa transição de forma estruturada. Se eu pudesse desenhar um plano de seis meses, com etapas semanais ou mensais, seria o ideal. Foco total em Product Manager de produtos de IA, usando minha experiência de backend como diferencial competitivo."
      ),
      Honchox.Peer.message(
        agent,
        "Perfeito. Então, resumindo: você é o Rafael, engenheiro de backend Elixir, quer migrar para Product Manager de produtos de IA. Precisa de um plano de seis meses cobrindo discovery, roadmap, métricas, LLMs, portfólio, entrevistas e inglês. Certo?"
      ),

      # -- Secondary plans --
      Honchox.Peer.message(
        user,
        "Isso! Esse é o plano principal. Mas tenho outros sonhos também. Um deles é, no futuro, empreender com uma startup de agentes inteligentes focada em pequenas empresas. Imagina uma plataforma onde agentes cuidam de atendimento ao cliente, operações internas, análise financeira e automações administrativas. Mas esse é um plano mais distante, talvez para daqui a cinco ou sete anos."
      ),
      Honchox.Peer.message(
        agent,
        "Olha, combina bastante com a sua visão. Uma plataforma de agentes pra pequenas empresas é uma ideia com potencial real. Mas você está certo em priorizar a transição para PM primeiro — é o passo que te dá a base de produto que você vai precisar pra empreender depois."
      ),
      Honchox.Peer.message(
        user,
        "Exatamente. Também penso em, paralelamente, contribuir com comunidades de tecnologia — escrever artigos, mentorar pessoas entrando na área, quem sabe dar palestras. Mas de novo: o foco agora é a preparação para Product Manager de IA. O resto é consequência."
      ),
      Honchox.Peer.message(
        agent,
        "Comunidade é importante, mas entendi a prioridade. Vou guardar esses três planos: (1) transição para Product Manager de produtos de IA no curto prazo, (2) startup de agentes inteligentes no médio/longo prazo, (3) contribuição com comunidades de tecnologia como plano paralelo. O plano de seis meses deve focar exclusivamente no primeiro. Pode confiar."
      ),
      Honchox.Peer.message(
        user,
        "Isso mesmo. Se no futuro eu pedir um plano de seis meses, quero que seja especificamente sobre a preparação para Product Manager de IA, não sobre a startup, não sobre carreira técnica pura, e definitivamente não sobre assuntos domésticos. Um plano prático com cronograma de estudo, portfólio, entrevistas simuladas, projetos de IA e posicionamento de mercado."
      )
    ]
  end

  defp sink_messages(user, agent) do
    [
      Honchox.Peer.message(
        user,
        "Mudando totalmente de assunto: minha pia da cozinha está vazando embaixo, perto do sifão. A água fica acumulando no fundo do armário e eu não sei por onde começar. Acontece mais quando a cuba está cheia ou quando deixo a torneira aberta por bastante tempo."
      ),
      Honchox.Peer.message(
        agent,
        "Isso tem cara de problema na vedação do sifão ou na conexão com o cano da parede. Primeiro passo: seca bem toda a área, coloca papel toalha seco em volta das conexões e abre a torneira devagar. A primeira gota vai te mostrar exatamente de onde está vazando. Consegue fazer esse teste?"
      ),
      Honchox.Peer.message(
        user,
        "Fiz isso. Encontrei umidade bem na rosca de baixo do sifão, onde ele conecta no cano que vai pra parede. Apertei com a mão mesmo, mas ainda pinga um pouco quando a cuba enche bastante."
      ),
      Honchox.Peer.message(
        agent,
        "Se apertou e ainda pinga, provavelmente a arruela de vedação está ressecada ou desgastada. Você sabe que tipo de sifão é? Tem um modelo com copo ou é daqueles sanfonados?"
      ),
      Honchox.Peer.message(
        user,
        "É um sifão de copo, daqueles de PVC comum. Achei isso aqui: quando desmontei a parte de baixo do copo, saiu bastante sujeira acumulada, cabelo e resto de comida. Limpei tudo e montei de novo, mas o vazamento continua naquela conexão de cima, perto da rosca."
      ),
      Honchox.Peer.message(
        agent,
        "Bom, pelo menos a limpeza já foi feita. O vazamento perto da rosca superior geralmente é por conta da arruela de borracha que fica entre o copo e o corpo do sifão. Com o tempo ela resseca e perde a vedação. Você consegue levar a arruela velha numa loja de material de construção pra comprar uma igual?"
      ),
      Honchox.Peer.message(
        user,
        "Posso consertar isso eu mesmo? Não queria ter que chamar encanador pra uma coisa simples. Se for só trocar a arruela e vedar com fita veda-rosca, eu faço."
      ),
      Honchox.Peer.message(
        agent,
        "Consegue sim, é bem tranquilo. Compra a arruela nova, um rolo de fita veda-rosca e vedante de silicone pra encanamento. Desmonta a conexão, substitui a arruela velha, passa fita veda-rosca na rosca (umas três voltas no sentido da rosca), monta de novo e testa com a cuba cheia. Se ainda pingar, aplica o vedante de silicone na junta externa como reforço. Resolve em meia hora."
      ),
      Honchox.Peer.message(
        user,
        "Ótimo, vou tentar isso. Mas fiquei pensando: tem algum jeito de eu saber se o problema é mais sério, tipo um cano rachado atrás da parede?"
      ),
      Honchox.Peer.message(
        agent,
        "Se o vazamento só acontece quando você usa a pia e para completamente quando a torneira está fechada e a cuba vazia, é quase certo que é vedação, não cano rachado. Cano rachado atrás da parede vazaria o tempo todo, mesmo com tudo seco. Mas quando você trocar a arruela, aproveita e passa a mão no cano que vai pra parede pra sentir se tem umidade — se tiver, aí sim é caso de encanador."
      ),
      Honchox.Peer.message(
        user,
        "Perfeito, entendi. Isso não tem nada a ver com meus planos profissionais, claro — é só um perrengue doméstico. Mas bom saber que eu mesmo consigo resolver. Vou na loja amanhã e tento o reparo. Depois conto se deu certo."
      ),
      Honchox.Peer.message(
        agent,
        "Isso, o problema da pia é um assunto doméstico separado dos seus objetivos de carreira. Foco agora é trocar arruela e veda-rosca no sifão. Depois me conta!"
      )
    ]
  end

  defp final_session(client, user, agent) do
    with {:ok, session} <-
           Honchox.session(client, "03-plano-6-meses",
             metadata: %{topic: "future_goal_plan"},
             configuration: %{reasoning: %{enabled: true}, peer_card: %{use: true, create: true}}
           ),
         :ok <- Honchox.Session.add_peers(session, [user, agent]),
         :ok <- Honchox.Session.set_peer_configuration(session, user, %{observe_me: true}),
         :ok <- Honchox.Session.set_peer_configuration(session, agent, %{observe_others: true}),
         {:ok, _messages} <-
           Honchox.Session.add_messages(session, [
             Honchox.Peer.message(
               user,
               "Oi de novo! Passou um tempo desde nossa última conversa. Eu continuei estudando um pouco de product discovery por conta própria, li alguns artigos sobre métricas de produto e vi uns cases de PMs que fizeram transição de engenharia."
             ),
             Honchox.Peer.message(
               agent,
               "Que legal, Rafael! Isso já é um começo. O que mais te chamou atenção nesses artigos e cases que você viu?"
             ),
             Honchox.Peer.message(
               user,
               "O que mais me marcou foi que Product Managers que vieram da engenharia têm uma vantagem enorme em times de IA: eles entendem a viabilidade técnica, falam a língua dos engenheiros e conseguem fazer trade-offs melhores entre escopo e complexidade. Só que precisam desenvolver bastante a parte de discovery, pesquisa com usuário e visão de negócio."
             ),
             Honchox.Peer.message(
               agent,
               "Exatamente. O gap não é técnico, é de produto. E é aí que um plano estruturado faz diferença. Você mencionou antes que queria um plano de seis meses focado na transição. Ainda quer?"
             ),
             Honchox.Peer.message(
               user,
               "Quero sim. Pode criar um plano de 6 meses para eu me preparar especificamente para virar Product Manager de produtos de IA? Quero algo bem prático, com cronograma de estudos, projetos para portfólio, prática de entrevistas e posicionamento de mercado. Usa minha experiência de backend Elixir como diferencial."
             )
           ]) do
      IO.puts("[OK] seeded 03-plano-6-meses (specific planning request)")
      {:ok, session}
    end
  end

  defp wait_for_scoped_queue(session, agent, user) do
    IO.puts("\n=== Queue status polling ===")
    wait_for_scoped_queue(session, agent, user, 1, 12)
  end

  defp wait_for_scoped_queue(session, agent, user, attempt, max_attempts) do
    with {:ok, status} <- Honchox.Session.queue_status(session),
         {:ok, scoped_status} <-
           Honchox.Session.queue_status(session, observer: agent, sender: user) do
      IO.puts(
        "Attempt #{attempt}/#{max_attempts}: session=#{inspect(status)} agent->user=#{inspect(scoped_status)}"
      )

      if queue_idle?(scoped_status) or attempt == max_attempts do
        :ok
      else
        Process.sleep(10_000)
        wait_for_scoped_queue(session, agent, user, attempt + 1, max_attempts)
      end
    end
  end

  defp queue_idle?(%Honchox.QueueStatus{pending_work_units: pending}), do: zero_or_nil?(pending)

  defp zero_or_nil?(nil), do: true
  defp zero_or_nil?(0), do: true
  defp zero_or_nil?(_), do: false

  defp evaluate_context(agent, user, final_session) do
    IO.puts("\n=== Retrieved context for final goal-specific prompt ===")
    IO.puts("Final query: #{@final_query}")

    {:ok, self_messages} = Honchox.Peer.search(user, @final_query, target: user, limit: 10)
    {:ok, agent_messages} = Honchox.Peer.search(agent, @final_query, target: user, limit: 10)

    {:ok, agent_context} =
      Honchox.Peer.context(agent,
        target: user,
        search_query: @final_query,
        search_top_k: 10,
        max_conclusions: 50,
        include_most_frequent: true
      )

    {:ok, user_context} =
      Honchox.Peer.context(user,
        target: user,
        search_query: @final_query,
        search_top_k: 10,
        max_conclusions: 50,
        include_most_frequent: true
      )

    {:ok, session_representation} =
      Honchox.Session.representation(final_session, agent,
        target: user,
        search_query: @final_query,
        search_top_k: 10,
        max_conclusions: 50,
        include_most_frequent: true
      )

    {:ok, agent_conclusions} =
      agent
      |> Honchox.Peer.conclusions_of(user)
      |> Honchox.ConclusionScope.query(@final_query, limit: 10)

    {:ok, user_conclusions} =
      user
      |> Honchox.Peer.conclusions()
      |> Honchox.ConclusionScope.query(@final_query, limit: 10)

    print_result(
      self_messages,
      agent_messages,
      agent_context,
      user_context,
      session_representation,
      agent_conclusions,
      user_conclusions
    )

    combined_text =
      [agent_context.representation, user_context.representation, session_representation] ++
        Enum.map(self_messages, & &1.content) ++
        Enum.map(agent_messages, & &1.content) ++
        Enum.map(agent_conclusions, & &1.content) ++ Enum.map(user_conclusions, & &1.content)

    combined_text =
      combined_text
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")
      |> String.downcase()

    missing = Enum.reject(@required_goal_anchors, &String.contains?(combined_text, &1))

    cond do
      missing != [] ->
        {:error, "missing expected goal anchors: #{inspect(missing)}"}

      not String.contains?(combined_text, @non_goal_anchor) ->
        IO.puts("\nGoal-specific retrieval did not need the sink anchor: #{@non_goal_anchor}")
        :ok

      true ->
        IO.puts(
          "\nNote: sink context also appeared in retrieved text; final goal anchors still passed."
        )

        :ok
    end
  rescue
    match_error in MatchError -> {:error, match_error.term}
  end

  defp print_result(
         self_messages,
         agent_messages,
         agent_context,
         user_context,
         session_representation,
         agent_conclusions,
         user_conclusions
       ) do
    IO.puts("\nSearch messages user -> user:")
    Enum.each(self_messages, &IO.puts("- #{&1.content}"))

    IO.puts("\nSearch messages agent -> user:")
    Enum.each(agent_messages, &IO.puts("- #{&1.content}"))

    IO.puts("\nPeer.context representation(agent -> user):")
    IO.puts(inspect(agent_context.representation))
    IO.puts("Peer.context peer_card(agent -> user): #{inspect(agent_context.peer_card)}")

    IO.puts("\nPeer.context representation(user -> user):")
    IO.puts(inspect(user_context.representation))
    IO.puts("Peer.context peer_card(user -> user): #{inspect(user_context.peer_card)}")

    IO.puts("\nSession.representation(agent -> user):")
    IO.puts(inspect(session_representation))

    IO.puts("\nConclusion query(agent -> user):")
    Enum.each(agent_conclusions, &IO.puts("- #{&1.content}"))

    IO.puts("\nConclusion query(user -> user):")
    Enum.each(user_conclusions, &IO.puts("- #{&1.content}"))
  end
end

LiveCrossSessionMemoryTest.run()
