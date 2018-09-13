defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.Component
  alias Skitter.Component.Instance

  component Identity, in: value, out: value do
    react value do
      value ~> value
    end
  end

  component Features, in: [foo, bar] do
    "Doesn't do anything useful, but allows us to show all component aspects."

    effect state_change hidden
    effect external_effect

    fields f

    init {a, b} do
      f <~ (a + b)
    end

    react _foo, _bar do
    end

    create_checkpoint do
      f
    end

    clean_checkpoint _ do
    end

    restore_checkpoint v do
      f <~ v
    end
  end

  def example_instance() do
    {:ok, inst} = init(Identity, nil)
    inst
  end

  doctest Skitter.Component
end
