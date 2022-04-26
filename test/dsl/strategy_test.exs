defmodule Skitter.DSL.StrategyTest do
  use ExUnit.Case, async: true

  alias Skitter.Strategy.Context
  import Skitter.DSL.Strategy

  doctest Skitter.DSL.Strategy

  defstrategy Clauses do
    defhook g(x) when x > 5, do: :gt
    defhook g(x) when x < 5, do: :lt
    defhook g(_), do: :eq
  end

  test "multiple hook clauses" do
    assert Clauses.g(%Context{}, 3) == :lt
    assert Clauses.g(%Context{}, 5) == :eq
    assert Clauses.g(%Context{}, 8) == :gt
  end
end
