# Live multi-tenant smoke test against Honcho's default API base URL.
#
# Usage:
#   env -u HONCHO_URL mix run scripts/live_multi_tenant_test.exs
#
# Requires:
#   HONCHO_API_KEY
#
# This script intentionally clears HONCHO_URL so a shell/zshrc override does not
# point the test at a self-hosted instance.

System.delete_env("HONCHO_URL")

defmodule LiveMultiTenantTest do
  @tenant_count 2

  def run do
    started_at = DateTime.utc_now() |> DateTime.to_unix()
    suffix = "#{started_at}-#{System.unique_integer([:positive])}"

    admin = Honchox.new(timeout: 20_000, max_retries: 0)

    IO.puts("=== Honchox live multi-tenant smoke test ===")
    IO.puts("Base URL: #{admin.base_url}")
    IO.puts("Workspace default on admin client: #{admin.workspace_id}")
    IO.puts("HONCHO_URL env after cleanup: #{inspect(System.get_env("HONCHO_URL"))}")
    IO.puts("API key present: #{not is_nil(admin.api_key)}")
    IO.puts("")

    tenants =
      for idx <- 1..@tenant_count do
        %{
          label: "tenant_#{idx}",
          workspace_id: "honchox-live-tenant-#{idx}-#{suffix}",
          agent_peer_id: "support-agent",
          user_peer_id: "end-user",
          session_id: "conversation-main"
        }
      end

    results = Enum.map(tenants, &exercise_tenant(admin, &1))

    IO.puts("\n=== Cross-tenant check ===")
    Enum.each(results, &print_tenant_summary/1)

    failures = collect_failures(results)

    IO.puts("\n=== Summary ===")

    if failures == [] do
      IO.puts("PASS: all tenant setup and smoke checks succeeded.")
    else
      IO.puts("FAIL: #{length(failures)} failure(s).")
      Enum.each(failures, fn failure -> IO.puts("- #{failure}") end)
      System.halt(1)
    end
  end

  defp exercise_tenant(admin, tenant) do
    IO.puts("--- #{tenant.label} / workspace #{tenant.workspace_id} ---")

    client =
      Honchox.new(
        api_key: admin.api_key,
        workspace_id: tenant.workspace_id,
        timeout: 20_000,
        max_retries: 0
      )

    with_step(tenant, :workspace, fn -> Honchox.workspace(client, metadata: %{tenant: tenant.label}) end)
    |> then(fn result ->
      result
      |> put_step(:agent_peer, fn ->
        Honchox.peer(client, tenant.agent_peer_id,
          metadata: %{role: "agent", tenant: tenant.label}
        )
      end)
      |> put_step(:user_peer, fn ->
        Honchox.peer(client, tenant.user_peer_id,
          metadata: %{role: "user", tenant: tenant.label}
        )
      end)
      |> put_step(:session, fn ->
        Honchox.session(client, tenant.session_id,
          metadata: %{tenant: tenant.label, use_case: "multi_tenant_smoke"}
        )
      end)
      |> put_step(:add_peers, fn state ->
        Honchox.Session.add_peers(state.session, [state.agent_peer, state.user_peer])
      end)
      |> put_step(:add_messages, fn state ->
        messages = [
          Honchox.Peer.message(state.user_peer, "Hello from #{tenant.label}"),
          Honchox.Peer.message(state.agent_peer, "Acknowledged for #{tenant.label}")
        ]

        Honchox.Session.add_messages(state.session, messages)
      end)
      |> put_step(:list_peers, fn -> Honchox.peers(client, size: 20) end)
      |> put_step(:list_sessions, fn -> Honchox.sessions(client, size: 20) end)
      |> put_step(:list_messages, fn state -> Honchox.Session.messages(state.session, size: 20) end)
    end)
  end

  defp with_step(tenant, name, fun) do
    state = %{tenant: tenant, failures: [], client_base_url: nil}
    put_step(state, name, fun)
  end

  defp put_step(%{failures: failures} = state, name, fun) do
    if failures != [] do
      state
    else
      result =
        case Function.info(fun, :arity) do
          {:arity, 0} -> fun.()
          {:arity, 1} -> fun.(state)
        end

      case result do
        {:ok, value} ->
          print_ok(name, value)
          Map.put(state, name, value)

        :ok ->
          print_ok(name, :ok)
          Map.put(state, name, :ok)

        {:error, error} ->
          print_error(name, error)
          update_in(state.failures, &["#{state.tenant.label} #{name}: #{inspect(error)}" | &1])

        other ->
          print_error(name, other)
          update_in(state.failures, &["#{state.tenant.label} #{name}: unexpected #{inspect(other)}" | &1])
      end
    end
  end

  defp print_ok(name, value) do
    IO.puts("[OK] #{name}: #{summarize(value)}")
  end

  defp print_error(name, error) do
    IO.puts("[ERROR] #{name}: #{inspect(error)}")
  end

  defp summarize(%Honchox.Workspace{id: id, metadata: metadata}),
    do: "%Honchox.Workspace{id: #{inspect(id)}, metadata: #{inspect(metadata)}}"

  defp summarize(%Honchox.Peer{id: id, workspace_id: workspace_id, metadata: metadata}),
    do: "%Honchox.Peer{id: #{inspect(id)}, workspace_id: #{inspect(workspace_id)}, metadata: #{inspect(metadata)}}"

  defp summarize(%Honchox.Session{id: id, workspace_id: workspace_id, metadata: metadata}),
    do: "%Honchox.Session{id: #{inspect(id)}, workspace_id: #{inspect(workspace_id)}, metadata: #{inspect(metadata)}}"

  defp summarize(%Honchox.Page{items: items, pages: pages}),
    do: "%Honchox.Page{items_count: #{length(items)}, pages: #{inspect(pages)}, item_ids: #{inspect(Enum.map(items, &item_id/1))}}"

  defp summarize(messages) when is_list(messages),
    do: "list(count: #{length(messages)}, ids: #{inspect(Enum.map(messages, &item_id/1))})"

  defp summarize(:ok), do: ":ok"
  defp summarize(value), do: inspect(value)

  defp item_id(%{id: id}), do: id
  defp item_id(%{content: content}), do: content
  defp item_id(value), do: inspect(value)

  defp print_tenant_summary(%{tenant: tenant, failures: failures} = result) do
    status = if failures == [], do: "OK", else: "FAILED"
    peer_ids = result |> Map.get(:list_peers) |> page_ids()
    session_ids = result |> Map.get(:list_sessions) |> page_ids()
    message_contents = result |> Map.get(:list_messages) |> page_contents()

    IO.puts("#{tenant.label}: #{status}")
    IO.puts("  workspace_id: #{tenant.workspace_id}")
    IO.puts("  peers visible in tenant workspace: #{inspect(peer_ids)}")
    IO.puts("  sessions visible in tenant workspace: #{inspect(session_ids)}")
    IO.puts("  messages in session: #{inspect(message_contents)}")
  end

  defp page_ids(%Honchox.Page{items: items}), do: Enum.map(items, &item_id/1)
  defp page_ids(_), do: []

  defp page_contents(%Honchox.Page{items: items}), do: Enum.map(items, &Map.get(&1, :content))
  defp page_contents(_), do: []

  defp collect_failures(results) do
    results
    |> Enum.flat_map(&Enum.reverse(&1.failures))
  end
end

LiveMultiTenantTest.run()
