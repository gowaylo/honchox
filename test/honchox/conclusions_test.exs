defmodule Honchox.ConclusionsTest do
  use ExUnit.Case

  test "legacy raw-map conclusion endpoints are not exposed as public SDK API" do
    if Code.ensure_loaded?(Honchox.Conclusions) do
      refute_exported(Honchox.Conclusions, :list, 1)
      refute_exported(Honchox.Conclusions, :list, 2)
      refute_exported(Honchox.Conclusions, :query, 2)
      refute_exported(Honchox.Conclusions, :query, 3)
      refute_exported(Honchox.Conclusions, :create, 2)
      refute_exported(Honchox.Conclusions, :create, 3)
      refute_exported(Honchox.Conclusions, :delete, 2)
      refute_exported(Honchox.Conclusions, :delete, 3)
      refute_exported(Honchox.Conclusions, :representation, 1)
      refute_exported(Honchox.Conclusions, :representation, 2)
    end
  end

  defp refute_exported(module, function, arity) do
    refute function_exported?(module, function, arity),
           "expected #{inspect(module)}.#{function}/#{arity} not to be public"
  end
end
