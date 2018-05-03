defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.Component

  # ---------------- #
  # Extra Assertions #
  # ---------------- #

  defmacro assert_definition_error(do: body) do
    quote do
      assert_raise Skitter.Component.DefinitionError, fn -> unquote(body) end
    end
  end

  # ----- #
  # Tests #
  # ----- #

  doctest Skitter.Component

  test "if names are generated correctly" do
    component(Dot.In.Name, [in: []], do: nil)
    component(SimpleName, [in: []], do: nil)
    component(ACRTestACR, [in: []], do: nil)

    assert name(Dot.In.Name) == "Name"
    assert name(SimpleName) == "Simple Name"
    assert name(ACRTestACR) == "ACR Test ACR"
  end

  test "if descriptions work as they should" do
    component EmptyDescription, in: [] do
    end

    component NormalDescription, in: [] do
      "Description"
    end

    component WithExpression, in: [] do
      "Description"
      5 + 2
    end

    component MultilineDescription, in: [] do
      """
      Description
      """
    end

    assert description(EmptyDescription) == ""
    assert description(NormalDescription) == "Description"
    assert description(WithExpression) == "Description"
    assert String.trim(description(MultilineDescription)) == "Description"
  end

  test "If correct ports are accepted" do
    # Should not raise
    component CorrectPorts, in: [foo, bar], out: test do
    end
  end

  test "if effects are parsed correctly" do
    # If effect properties are ever used, be sure to add them here
    component EffectTest, in: [] do
      effect internal_state
      effect external_effects
    end

    assert EffectTest |> effects() |> Keyword.get(:internal_state) == []
    assert EffectTest |> effects() |> Keyword.get(:external_effects) == []
  end

  test "if init works" do
    component TestInit, in: [] do
      init(a, b, do: instance!(a * b))
    end

    assert TestInit.__skitter_init__([3, 4]) == {:ok, 3 * 4}
  end

  test "if helpers work" do
    component TestHelper, in: [] do
      init(do: instance!(worker()))

      helper worker do
        :from_helper
      end
    end

    assert TestHelper.__skitter_init__([]) == {:ok, :from_helper}
  end

  test "if react works" do
    component TestSpit, in: [foo], out: out do
      react foo do
        spit foo ~> out
      end
    end

    assert TestSpit.__skitter_react__(nil, [10]) == {:ok, nil, [out: 10]}
  end

  test "if instances work correctly" do
    component TestInstance, in: [foo] do
      effect internal_state

      init(arg, do: instance!(arg))

      react foo do
        new = instance + foo
        instance! new
      end
    end

    {:ok, inst} = TestInstance.__skitter_init__([10])
    assert inst == 10

    {:ok, inst, []} = TestInstance.__skitter_react__(inst, [5])
    assert inst == 15
  end

  test "if after_failure works as it should" do
    component TestAfterFailure, in: [] do
      effect external_effects

      react do
        after_failure do
          raise "some error"
        end
      end
    end

    # should not raise
    TestAfterFailure.__skitter_react__(nil, [])

    assert_raise RuntimeError, fn ->
      TestAfterFailure.__skitter_react_after_failure__(nil, [])
    end
  end

  # Error Reporting
  # ---------------

  test "if incorrect effects are reported" do
    assert_definition_error do
      component WrongEffects, in: [] do
        effect does_not_exist
      end
    end
  end

  test "if incorrect effect properties are reported" do
    assert_definition_error do
      component WrongPropertySyntax, in: [] do
        effect internal_state 5
      end
    end

    assert_definition_error do
      component WrongEffectProperties, in: [] do
        effect internal_state foo
      end
    end
  end

  test "if incorrect use of react after_failure is reported" do
    assert_definition_error do
      component WrongAfterFailure, in: [val] do
        react val do
          after_failure do
          end
        end
      end
    end
  end

  test "if incorrect instance! use is reported" do
    assert_definition_error do
      component WrongInstance, in: [] do
        react do
          instance! 30
        end
      end
    end
  end

  test "if incorrectly named ports are reported" do
    assert_definition_error do
      component SymbolPorts, in: [:foo, :bar] do
      end
    end

    assert_definition_error do
      component SymbolInSpit, in: [], out: [:foo] do
        react do
          spit(42) ~> :foo
        end
      end
    end
  end

  test "if a wrong react signature is reported" do
    assert_definition_error do
      component WrongInPorts, in: [:a, :b, :c] do
        react a, b do
        end
      end
    end
  end

  test "if incorrect port use in react is reported" do
    assert_definition_error do
      component WrongSpit, in: [], out: [:foo] do
        react do
          spit 42 ~> bar
        end
      end
    end
  end
end
