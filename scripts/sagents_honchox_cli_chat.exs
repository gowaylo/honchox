# Interactive Sagents + Honchox CLI chat.
#
# Usage:
#   OPENROUTER_API_KEY=... HONCHO_API_KEY=... mix run scripts/sagents_honchox_cli_chat.exs
#
# Optional env:
#   OPENROUTER_MODEL=deepseek/deepseek-v4-flash
#   HONCHO_WORKSPACE_ID=my-workspace
#   HONCHO_ASSISTANT_PEER_ID=assistant
#   HONCHO_USER_PEER_ID=user
#   HONCHO_URL=https://api.honcho.dev
#
# Commands inside the chat:
#   /help                         Show commands
#   /remember <text>              Store a manual conclusion about the user
#   /context [query]              Print Honcho peer context for the user
#   /queue                        Print Honcho queue status
#   /exit                         Quit

if "--help" in System.argv() or "-h" in System.argv() do
  IO.puts("""
  Interactive Sagents + Honchox CLI chat

  Required env:
    OPENROUTER_API_KEY
    HONCHO_API_KEY

  Optional env:
    OPENROUTER_MODEL=deepseek/deepseek-v4-flash
    HONCHO_WORKSPACE_ID=honchox-sagents-cli
    HONCHO_ASSISTANT_PEER_ID=assistant
    HONCHO_USER_PEER_ID=user
    HONCHO_URL=https://api.honcho.dev

  Run:
    mix run scripts/sagents_honchox_cli_chat.exs
  """)

  System.halt(0)
end

alias LangChain.ChatModels.ChatOpenAI
alias LangChain.{Function, Message}
alias Sagents.{Agent, State}

openrouter_key =
  System.get_env("OPENROUTER_API_KEY") ||
    raise "Set OPENROUTER_API_KEY before running this script"

honcho_key =
  System.get_env("HONCHO_API_KEY") ||
    raise "Set HONCHO_API_KEY before running this script"

model_name = System.get_env("OPENROUTER_MODEL") || "deepseek/deepseek-v4-flash"
workspace_id = System.get_env("HONCHO_WORKSPACE_ID") || "honchox-sagents-cli"
assistant_peer_id = System.get_env("HONCHO_ASSISTANT_PEER_ID") || "assistant"
user_peer_id = System.get_env("HONCHO_USER_PEER_ID") || "user"
honcho_url = System.get_env("HONCHO_URL") || "https://api.honcho.dev"

client =
  Honchox.new(
    api_key: honcho_key,
    workspace_id: workspace_id,
    base_url: honcho_url,
    timeout: 60_000,
    max_retries: 1
  )

with {:ok, _workspace} <- Honchox.workspace(client),
     {:ok, _assistant_peer} <-
       Honchox.peer(client, assistant_peer_id,
         metadata: %{role: "assistant", source: "sagents_cli"},
         configuration: %{observe_me: false}
       ),
     {:ok, _user_peer} <-
       Honchox.peer(client, user_peer_id,
         metadata: %{role: "user", source: "sagents_cli"},
         configuration: %{observe_me: true}
       ) do
  :ok
else
  {:error, error} ->
    IO.puts("Failed to initialize Honcho resources: #{inspect(error, pretty: true)}")
    System.halt(1)
end

model =
  ChatOpenAI.new!(%{
    endpoint: "https://openrouter.ai/api/v1/chat/completions",
    api_key: openrouter_key,
    model: model_name,
    temperature: 0.2,
    max_tokens: 1_200,
    parallel_tool_calls: false,
    req_config: %{
      headers: [
        {"HTTP-Referer", "https://github.com/go-waylo/honchox"},
        {"X-Title", "Honchox Sagents CLI chat"}
      ]
    }
  })

project_root = Path.expand("..", __DIR__)

project_file_tool =
  Function.new!(%{
    name: "honchox_project_file",
    description:
      "Inspect the local Honchox project. Use it to list files, read source/docs, or grep for implementation details before answering project-specific questions.",
    parameters_schema: %{
      type: "object",
      properties: %{
        action: %{
          type: "string",
          enum: ["list", "read", "grep"],
          description: "list files, read a file, or grep project text"
        },
        path: %{
          type: "string",
          description: "Relative file or directory path for list/read. Defaults to project root."
        },
        query: %{
          type: "string",
          description: "Search text for grep action"
        },
        limit: %{
          type: "integer",
          description: "Maximum entries/lines/results. Defaults to 80, max 200."
        }
      },
      required: ["action"]
    },
    function: fn args, _context ->
      action = Map.fetch!(args, "action")
      limit = min(Map.get(args, "limit", 80), 200)
      relative_path = Map.get(args, "path", ".")

      safe_path = fn path ->
        expanded = Path.expand(path, project_root)

        if expanded == project_root or String.starts_with?(expanded, project_root <> "/") do
          {:ok, expanded}
        else
          {:error, "Path escapes project root"}
        end
      end

      case {action, safe_path.(relative_path)} do
        {_, {:error, reason}} ->
          {:error, reason}

        {"list", {:ok, path}} ->
          if File.dir?(path) do
            entries =
              path
              |> File.ls!()
              |> Enum.sort()
              |> Enum.take(limit)

            {:ok,
             %{root: project_root, path: Path.relative_to(path, project_root), entries: entries}}
          else
            {:error, "Not a directory: #{relative_path}"}
          end

        {"read", {:ok, path}} ->
          if File.regular?(path) do
            content =
              path
              |> File.stream!([], :line)
              |> Enum.take(limit)
              |> Enum.join()

            {:ok,
             %{
               path: Path.relative_to(path, project_root),
               content: content,
               truncated_to_lines: limit
             }}
          else
            {:error, "Not a regular file: #{relative_path}"}
          end

        {"grep", {:ok, path}} ->
          query = Map.get(args, "query") || ""

          if query == "" do
            {:error, "grep requires query"}
          else
            {output, _status} =
              System.cmd(
                "rg",
                [
                  "--line-number",
                  "--fixed-strings",
                  "--glob",
                  "!deps/**",
                  "--glob",
                  "!_build/**",
                  query,
                  path
                ],
                stderr_to_stdout: true
              )

            results = output |> String.split("\n", trim: true) |> Enum.take(limit)
            {:ok, %{query: query, results: results, truncated_to_results: limit}}
          end

        {other, _} ->
          {:error, "Unknown action: #{inspect(other)}"}
      end
    end
  })

{:ok, agent} =
  Agent.new(
    %{
      agent_id: "honchox-sagents-cli-chat",
      model: model,
      base_system_prompt: """
      You are a personal technical assistant for the Honchox project.

      Your job is to help Lucas understand, validate, and integrate Honchox:
      - explain the public API and optional integrations;
      - inspect the local Honchox code before answering implementation-specific questions;
      - propose usage patterns, examples, and tests;
      - use Honchox memory tools to remember project preferences and prior decisions.

      Available tool groups:
      - Honchox memory tools for semantic memory, conclusions, dreams, and queue status.
      - honchox_project_file to inspect this local repository.

      Memory identity:
      - Your observer peer id is #{assistant_peer_id}.
      - The human/user observed peer id is #{user_peer_id}.
      - When searching or writing user memory, use observer_id=#{assistant_peer_id} and observed_id/target_id=#{user_peer_id}.

      Use honchox_project_file before answering questions about current source code,
      module names, APIs, scripts, tests, docs, or integration details. Use Honchox
      memory tools before answering questions that depend on prior context,
      preferences, profile facts, or memories. Be concise in the CLI.
      """,
      tools: [project_file_tool],
      middleware: [{Honchox.Sagents.Tools, client: client}],
      max_runs: 12
    },
    replace_default_middleware: true
  )

state = State.new!(%{messages: []})

IO.puts("""
Honchox project assistant CLI chat
Workspace: #{workspace_id}
Model: #{model_name}
Assistant peer: #{assistant_peer_id}
User peer: #{user_peer_id}
Project root: #{project_root}
Type /help for commands, /exit to quit.
""")

loop = fn loop, state ->
  input = IO.gets("you> ")

  cond do
    is_nil(input) ->
      IO.puts("\nbye")
      state

    String.trim(input) == "" ->
      loop.(loop, state)

    String.trim(input) in ["/exit", "/quit"] ->
      IO.puts("bye")
      state

    String.trim(input) == "/help" ->
      IO.puts("""
      Commands:
        /remember <text>   Store a manual Honcho conclusion about you
        /context [query]   Show Honcho context about you
        /queue             Show Honcho async queue status
        /exit              Quit
      """)

      loop.(loop, state)

    String.starts_with?(String.trim(input), "/remember ") ->
      memory = input |> String.trim() |> String.replace_prefix("/remember ", "")

      with {:ok, assistant_peer} <- Honchox.peer(client, assistant_peer_id),
           {:ok, conclusions} <-
             assistant_peer
             |> Honchox.Peer.conclusions_of(user_peer_id)
             |> Honchox.ConclusionScope.create(memory) do
        IO.puts("stored #{length(conclusions)} conclusion(s)")
      else
        {:error, error} -> IO.puts("remember failed: #{inspect(error, pretty: true)}")
      end

      loop.(loop, state)

    String.starts_with?(String.trim(input), "/context") ->
      query = input |> String.trim() |> String.replace_prefix("/context", "") |> String.trim()

      opts =
        if query == "",
          do: [target: user_peer_id],
          else: [target: user_peer_id, search_query: query]

      with {:ok, assistant_peer} <- Honchox.peer(client, assistant_peer_id),
           {:ok, context} <- Honchox.Peer.context(assistant_peer, opts) do
        IO.inspect(context, label: "context", pretty: true, limit: :infinity)
      else
        {:error, error} -> IO.puts("context failed: #{inspect(error, pretty: true)}")
      end

      loop.(loop, state)

    String.trim(input) == "/queue" ->
      case Honchox.queue_status(client, observer: assistant_peer_id, sender: user_peer_id) do
        {:ok, status} -> IO.inspect(status, label: "queue", pretty: true)
        {:error, error} -> IO.puts("queue failed: #{inspect(error, pretty: true)}")
      end

      loop.(loop, state)

    true ->
      user_text = String.trim(input)

      state = %{
        state
        | messages:
            state.messages ++
              [
                Message.new_user!("""
                #{user_text}

                Memory routing hint: if you use Honchox tools, observer_id is #{assistant_peer_id} and target/observed peer is #{user_peer_id}.
                """)
              ]
      }

      case Agent.execute(agent, state) do
        {:ok, next_state} ->
          assistant_message = List.last(next_state.messages)
          content = Map.get(assistant_message, :content) || inspect(assistant_message)
          IO.puts("agent> #{content}\n")
          loop.(loop, next_state)

        {:interrupt, next_state, interrupt_data} ->
          IO.puts("agent interrupted: #{inspect(interrupt_data, pretty: true)}")
          loop.(loop, next_state)

        {:error, error} ->
          IO.puts("agent error: #{inspect(error, pretty: true, limit: :infinity)}")
          loop.(loop, state)
      end
  end
end

loop.(loop, state)
