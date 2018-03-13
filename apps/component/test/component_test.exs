defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true
  doctest Skitter.Component
  import Skitter.Component

  @doc """
  Autogenerate part of the component definition.

  _Only use this in unit tests!_
  """
  defmacrop dummycomponent(
    name \\ TestComponent, effects \\ :no_effects, opts \\ [], do: body
  ) do
    quote do
      defcomponent unquote(name), unquote(effects), unquote(opts) do
        @in_ports []
        @out_ports []
        @desc ""
        unquote(body)
      end
    end
  end

  test "name generation" do
    dummycomponent FOOBarBaz do
    end

    dummycomponent NameTest do
      @name "name changed"
    end
    assert NameTest.name() == "name changed"
  end
end
