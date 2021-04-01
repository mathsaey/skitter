defmodule Skitter.DSL.StrategyTest do
  use ExUnit.Case, async: true

  alias Skitter.Strategy.Context
  import Skitter.DSL.Strategy

  # Makes our doctests a bit cleaner
  Code.put_compiler_option(:ignore_module_conflict, true)

  doctest Skitter.DSL.Strategy
end
