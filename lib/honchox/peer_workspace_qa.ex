defmodule Honchox.PeerWorkspaceQA do
  @moduledoc """
  Workspace-wide question answering flow for a peer.

  Orchestrates multiple Honcho endpoints — peer representation, peer context,
  and workspace search — to build a rich evidence bundle, then asks the peer
  chat endpoint to answer a natural-language question grounded in that evidence.

  This is a higher-level convenience on top of the primitives in
  `Honchox.Peers` and `Honchox.Workspaces`.

  ## Examples

      client = Honchox.new(api_key: "sk-...")

      {:ok, answer} = Honchox.PeerWorkspaceQA.ask(client, "alice",
        "What projects is alice working on?",
        workspace_id: "my-workspace"
      )

      answer["content"]
      #=> "Based on the evidence, alice is currently working on..."

  """

  @workspace_id "shared"
  @default_limit 8
  @default_reasoning_level "high"
  @max_section_chars 2_000

  @doc """
  Asks a question about a peer using workspace-wide context.

  Gathers the peer's representation, context, and workspace search results,
  then sends a grounded chat request. Returns the AI response along with all
  the evidence used.

  ## Options

    * `:workspace_id` — workspace to query (default: `"shared"`)
    * `:limit` — max search results to include (default: `8`)
    * `:reasoning_level` — reasoning depth: `"low"`, `"medium"`, or `"high"`
      (default: `"high"`)

  ## Return value

  On success, returns `{:ok, result}` where `result` is a map with:

    * `"content"` — the AI-generated answer
    * `"peer_id"` — the peer that was queried
    * `"workspace_id"` — the workspace used
    * `"representation"` — raw peer representation data
    * `"context"` — raw peer context data
    * `"workspace_results"` — raw workspace search results

  On failure, returns `{:error, error}` where the error body includes the
  `:step` that failed (`:representation`, `:context`, `:workspace_search`,
  or `:chat`).
  """
  @spec ask(Honchox.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def ask(%Honchox{} = client, peer_id, question, opts \\ []) when is_binary(peer_id) and is_binary(question) do
    workspace_id = Keyword.get(opts, :workspace_id, @workspace_id)
    limit = Keyword.get(opts, :limit, @default_limit)
    reasoning_level = Keyword.get(opts, :reasoning_level, @default_reasoning_level)

    with {:representation, {:ok, representation}} <- {:representation, fetch_representation(client, peer_id, question, workspace_id)},
         {:context, {:ok, context}} <- {:context, fetch_context(client, peer_id, question, workspace_id)},
         {:workspace_search, {:ok, workspace_results}} <-
           {:workspace_search, fetch_workspace_results(client, peer_id, question, workspace_id, limit)},
         prompt = build_prompt(peer_id, question, representation, context, workspace_results),
         {:chat, {:ok, response}} <-
           {:chat,
            Honchox.Peers.chat(
              client,
              peer_id,
              prompt,
              workspace_id: workspace_id,
              reasoning_level: reasoning_level
            )} do
      {:ok, success_response(peer_id, workspace_id, representation, context, workspace_results, response)}
    else
      {:representation, {:error, error}} -> {:error, annotate_error(:representation, error)}
      {:context, {:error, error}} -> {:error, annotate_error(:context, error)}
      {:workspace_search, {:error, error}} -> {:error, annotate_error(:workspace_search, error)}
      {:chat, {:error, error}} -> {:error, annotate_error(:chat, error)}
    end
  end

  defp success_response(peer_id, workspace_id, representation, context, workspace_results, response) do
    %{
      "content" => Map.get(response, "content"),
      "peer_id" => peer_id,
      "workspace_id" => workspace_id,
      "representation" => representation,
      "context" => context,
      "workspace_results" => workspace_results
    }
  end

  defp annotate_error(step, %Honchox.Error{} = error) do
    Map.put(error, :body, %{step: step, error_body: error.body})
  end

  defp annotate_error(step, error), do: %{step: step, error: error}

  defp fetch_representation(client, peer_id, question, workspace_id) do
    Honchox.Peers.representation(client, peer_id,
      workspace_id: workspace_id,
      search_query: question,
      search_top_k: @default_limit,
      include_most_frequent: true,
      max_conclusions: 12
    )
  end

  defp fetch_context(client, peer_id, question, workspace_id) do
    Honchox.Peers.context(client, peer_id,
      workspace_id: workspace_id,
      search_query: question,
      search_top_k: @default_limit,
      include_most_frequent: true,
      max_conclusions: 12
    )
  end

  defp fetch_workspace_results(client, peer_id, question, workspace_id, limit) do
    Honchox.Workspaces.search(client, workspace_query(peer_id, question),
      workspace_id: workspace_id,
      limit: limit
    )
  end

  defp workspace_query(peer_id, question) do
    [
      "peer:#{peer_id}",
      peer_id,
      question,
      "current projects languages active work recent context"
    ]
    |> Enum.join(" ")
  end

  defp build_prompt(peer_id, question, representation, context, workspace_results) do
    """
    Responda em linguagem natural sobre o peer "#{peer_id}" usando somente as evidencias abaixo.

    Regras:
    - Foque em atividade atual ou recente quando a pergunta pedir isso.
    - Se a evidencia for insuficiente, diga explicitamente o que nao foi possivel confirmar.
    - Nao invente projetos, linguagens ou fatos.
    - Seja direto e objetivo.

    Pergunta:
    #{question}

    Representacao do peer:
    #{compact_term(representation)}

    Contexto consolidado do peer:
    #{compact_term(context)}

    Resultados de busca no workspace:
    #{compact_term(workspace_results)}
    """
  end

  defp compact_term(term) do
    term
    |> encode_json()
    |> truncate(@max_section_chars)
  end

  defp encode_json(term) do
    Jason.encode_to_iodata!(term, pretty: true)
    |> IO.iodata_to_binary()
  end

  defp truncate(text, max_chars) when is_binary(text) and byte_size(text) <= max_chars, do: text

  defp truncate(text, max_chars) when is_binary(text) do
    binary_part(text, 0, max_chars) <> "\n...<truncated>"
  end
end
