defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  import Skitter.Component
  alias Skitter.Component.BadCallError
  alias Skitter.Component.DefinitionError

  # ------- #
  # Utility #
  # ------- #

  # Generate a dummy component. Only use this for unit tests!
  defmacrop dummycomponent(name, effects \\ [], opts \\ [], do: body) do
    quote do
        defcomponent unquote(name), unquote(effects), unquote(opts) do
          @desc "some documentation goes here"
          @in_ports []
          @out_ports []

          def init(_), do: {:ok, nil}
          defoverridable init: 1
          def react(_,_), do: {:ok, nil}
          defoverridable react: 2

          unquote(body)
        end
    end
  end

  # Incorrect effects cause errors at macro expansion time, which cannot
  # be caught by ex_unit.
  # We work around this by wrapping our code in a string.
  # This is horrible, but luckily it's only for testing purposes.
  defp build_and_eval_effect_string(effects) do
    Code.eval_string """
    import Skitter.Component
    defcomponent :"#{inspect(effects)}", #{inspect(effects)} do
      @desc "some documentation goes here"
      @in_ports []
      @out_ports []

      def init(_), do: {:ok, nil}
      def react(_,_), do: {:ok, nil}
    end
    """
  end

  # ----- #
  # Tests #
  # ----- #

  doctest Skitter.Component

  test "name generation" do
    dummycomponent FOOBarBaz do
    end
    assert FOOBarBaz.name == "FOO Bar Baz"

    dummycomponent NameTest do
      @name "name changed"
    end
    assert NameTest.name == "name changed"
  end

  test "description generation" do
    io = capture_io :stderr, fn ->
      defcomponent DescriptionGenerationWarn, :no_effects do
        @in_ports []
        @out_ports []
        def init(_), do: {:ok, nil}
        def react(_,_), do: {:ok, nil}
      end
    end
    assert io =~ "warning"
    assert DescriptionGenerationWarn.desc == ""

    defcomponent DescriptionGeneration, :no_effects do
      @desc "explanation"
      @in_ports []
      @out_ports []
      def init(_), do: {:ok, nil}
      def react(_,_), do: {:ok, nil}
    end
    assert DescriptionGeneration.desc == "explanation"
  end

  test "attribute generation" do
    dummycomponent AttrGenTest do
      @in_ports [:in]
      @out_ports [:top, :kek]
    end
    assert AttrGenTest.in_ports == [:in]
    assert AttrGenTest.out_ports == [:top, :kek]
  end

  test "missing attribute errors" do
    assert_raise DefinitionError, fn ->
      defcomponent AttrTest, :no_effects do
      end
    end
    assert_raise DefinitionError, fn ->
      defcomponent AttrTest, :no_effects do
        @in_ports []
      end
    end
    assert_raise DefinitionError, fn ->
      defcomponent AttrTest, :no_effects do
        @out_ports []
      end
    end
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

  test "overridable functions" do
    dummycomponent NoTerminate, do: nil
    assert NoTerminate.terminate(nil) == :ok
    dummycomponent Terminate do
      def terminate(_), do: :something_else
    end
    assert Terminate.terminate(nil) == :something_else
  end

  test "internal_state placeholders" do
    dummycomponent NoState, :no_effects, do: nil
    assert_raise BadCallError, fn -> NoState.checkpoint(nil) end
    assert_raise BadCallError, fn -> NoState.restore(nil) end
  end
end
