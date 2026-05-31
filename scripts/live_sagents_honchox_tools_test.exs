# Live Sagents + Honchox tools validation.
#
# Requires:
#   OPENROUTER_API_KEY
#   HONCHO_API_KEY
#
# Optional:
#   OPENROUTER_MODEL=deepseek/deepseek-v4-flash
#   HONCHO_WORKSPACE_ID=...
#
# Run:
#   elixir scripts/live_sagents_honchox_tools_test.exs

# Avoid local development overrides that point to a stopped/self-hosted Honcho.
System.delete_env("HONCHO_URL")

Mix.install([
  {:honchox, path: Path.expand("..", __DIR__)},
  {:sagents, "~> 0.7"}
])

alias LangChain.ChatModels.ChatOpenAI
alias LangChain.Message
alias Sagents.{Agent, State}

openrouter_key =
  System.get_env("OPENROUTER_API_KEY") ||
    raise "Set OPENROUTER_API_KEY before running this script"

honcho_key =
  System.get_env("HONCHO_API_KEY") ||
    raise "Set HONCHO_API_KEY before running this script"

workspace_id =
  System.get_env("HONCHO_WORKSPACE_ID") ||
    "honchox-sagents-live-#{System.system_time(:second)}"

model_name = System.get_env("OPENROUTER_MODEL") || "deepseek/deepseek-v4-flash"

client =
  Honchox.new(
    api_key: honcho_key,
    workspace_id: workspace_id,
    base_url: "https://api.honcho.dev"
  )

# Seed deterministic memory so the LLM has something useful to retrieve with the tool.
observer = "assistant"
observed = "lucas"
{:ok, peer} = Honchox.peer(client, observer)

{:ok, _conclusions} =
  peer
  |> Honchox.Peer.conclusions_of(observed)
  |> Honchox.ConclusionScope.create([
    "Lucas is validating the optional Honchox Sagents tools integration.",
    "For this validation, the secret phrase is sagents-honcho-ok."
  ])

model =
  ChatOpenAI.new!(%{
    endpoint: "https://openrouter.ai/api/v1/chat/completions",
    api_key: openrouter_key,
    model: model_name,
    temperature: 0.0,
    max_tokens: 600,
    parallel_tool_calls: false,
    req_config: %{
      headers: [
        {"HTTP-Referer", "https://github.com/go-waylo/honchox"},
        {"X-Title", "Honchox Sagents live validation"}
      ]
    }
  })

{:ok, agent} =
  Agent.new(
    %{
      agent_id: "honchox-sagents-live-test",
      model: model,
      base_system_prompt: """
      You are validating Honchox Sagents tools. You must use Honchox tools when
      asked about stored memory. Answer concisely and include the exact secret
      phrase if you find it.
      """,
      middleware: [
        {Honchox.Sagents.Tools, client: client}
      ],
      max_runs: 8
    },
    replace_default_middleware: true
  )

state =
  State.new!(%{
    messages: [
      Message.new_user!(
        "Use the Honchox tools to find what memory says about Lucas and report the secret phrase. Observer peer is assistant; observed/target peer is lucas. Do not guess."
      )
    ]
  })

IO.puts("Workspace: #{workspace_id}")
IO.puts("Model: #{model_name}")
IO.puts("Running Sagents agent with Honchox tools...")

case Agent.execute(agent, state) do
  {:ok, final_state} ->
    final = List.last(final_state.messages)
    IO.puts("\nFinal message:\n#{inspect(final, pretty: true, limit: :infinity)}")

    content = Map.get(final, :content) || inspect(final)

    if String.contains?(content, "sagents-honcho-ok") do
      IO.puts("\nPASS: model used/recovered Honchox memory secret phrase.")
    else
      IO.puts("\nCHECK MANUALLY: final response did not include the expected secret phrase.")
      System.halt(2)
    end

  other ->
    IO.puts("\nAgent execution failed or interrupted:")
    IO.inspect(other, pretty: true, limit: :infinity)
    System.halt(1)
end
