defmodule Honchox.PublicAPICleanupTest do
  use ExUnit.Case

  @legacy_modules [
    Honchox.Workspaces,
    Honchox.Peers,
    Honchox.Sessions,
    Honchox.PeerWorkspaceQA
  ]

  @legacy_root_http [
    get: 3,
    post: 3,
    put: 3,
    patch: 3,
    delete: 3,
    upload: 4
  ]

  test "old raw-map modules are not part of the public SDK surface" do
    Enum.each(@legacy_modules, fn module ->
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          public_functions = module.__info__(:functions) -- [module_info: 0, module_info: 1]

          assert public_functions == [],
                 "expected #{inspect(module)} to expose no public raw-map functions, got: #{inspect(public_functions)}"

        {:error, :nofile} ->
          :ok
      end
    end)
  end

  test "root Honchox module does not expose raw HTTP wrappers" do
    assert {:module, Honchox} = Code.ensure_loaded(Honchox)

    Enum.each(@legacy_root_http, fn {function, arity} ->
      refute function_exported?(Honchox, function, arity),
             "expected Honchox.#{function}/#{arity} not to be public; use SDK-shaped structs or Honchox.API internals instead"
    end)
  end

  test "SDK-shaped entry points remain public" do
    assert {:module, Honchox} = Code.ensure_loaded(Honchox)

    assert function_exported?(Honchox, :workspace, 2)
    assert function_exported?(Honchox, :peer, 3)
    assert function_exported?(Honchox, :peers, 2)
    assert function_exported?(Honchox, :session, 3)
    assert function_exported?(Honchox, :sessions, 2)

    assert {:module, Honchox.Peer} = Code.ensure_loaded(Honchox.Peer)
    assert {:module, Honchox.Session} = Code.ensure_loaded(Honchox.Session)

    assert function_exported?(Honchox.Peer, :chat, 3)
    assert function_exported?(Honchox.Peer, :context, 2)
    assert function_exported?(Honchox.Session, :messages, 2)
    assert function_exported?(Honchox.Session, :context, 2)
  end

  test "public docs, ExDoc extras, and retained scripts do not promote old raw-map workflows" do
    paths =
      Honchox.MixProject.project()
      |> Keyword.fetch!(:docs)
      |> Keyword.fetch!(:extras)
      |> Kernel.++(["mix.exs", "scripts/test_keys.exs"])
      |> Enum.uniq()

    Enum.each(paths, fn path ->
      text = File.read!(path)

      Enum.each(@legacy_modules ++ [Honchox.Conclusions, Honchox.Observations], fn module ->
        refute text =~ inspect(module),
               "expected #{path} not to promote legacy raw-map module #{inspect(module)}"
      end)
    end)
  end

  test "raw HTTP helper is hidden from the public documentation surface" do
    assert {:module, Honchox.HTTP} = Code.ensure_loaded(Honchox.HTTP)
    assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Honchox.HTTP)

    assert moduledoc == :hidden,
           "expected Honchox.HTTP to be internal/hidden from ExDoc; raw HTTP helpers are not SDK-shaped public API"
  end
end
