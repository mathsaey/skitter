defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  doctest Skitter.Component
  import Skitter.Component

  # Generate a dummy component. Only use this for unit tests!
  defmacrop dummycomponent(name, effects \\ [], opts \\ [], do: body) do
    quote do
        defcomponent unquote(name), unquote(effects), unquote(opts) do
          @in_ports []
          @out_ports []
          @desc ""
          unquote(body)
        end
    end
  end

  # Incorrect effects cause errors at macro expansion time.
  # We work around this by wrapping our code in a string.
  # This is horrible, but luckily it's only for testing purposes.
  defp build_and_eval_effect_string(effects) do
    Code.eval_string """
    import Skitter.Component
    defcomponent :"#{inspect(effects)}", #{inspect(effects)} do
      @desc ""
      @in_ports []
      @out_ports []
    end
    """
  end

  test "name generation" do
    dummycomponent FOOBarBaz do
    end

    dummycomponent NameTest do
      @name "name changed"
    end
    assert NameTest.name() == "name changed"
  end

  test "incorrect effect errors" do
    alias Skitter.Component.DefinitionError

    assert_raise DefinitionError, fn ->
      build_and_eval_effect_string 0
    end
    assert_raise DefinitionError, fn ->
      build_and_eval_effect_string [:no_effects]
    end
    assert_raise DefinitionError, fn ->
      build_and_eval_effect_string :invalid_effect
    end
    assert_raise DefinitionError, fn ->
      build_and_eval_effect_string [:invalid_effect]
    end
    assert_raise DefinitionError, fn ->
      build_and_eval_effect_string [:internal_state, :invalid_effect]
    end

    # Make sure these don't throw
    build_and_eval_effect_string []
    build_and_eval_effect_string :no_effects
    build_and_eval_effect_string :internal_state
    build_and_eval_effect_string :external_effects
    build_and_eval_effect_string [:internal_state]
    build_and_eval_effect_string [:external_effects]
    build_and_eval_effect_string [:internal_state, :external_effects]
  end

  test "missing attribute errors" do
    alias Skitter.Component.DefinitionError

    assert_raise DefinitionError, fn ->
      defcomponent AttrTest, :no_effects do
      end
    end
  end
end
