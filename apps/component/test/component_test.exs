defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.Component

  # ---------------- #
  # Extra Assertions #
  # ---------------- #

  defmacro assert_definition_error(do: body) do
    quote do
      assert_raise Skitter.Component.DefinitionError, fn -> unquote(body)
      end
    end
  end

  # ----- #
  # Tests #
  # ----- #

  doctest Skitter.Component

  test "if names are generated correctly" do
    component Dot.In.Name, [in: []], do: nil
    component SimpleName,  [in: []], do: nil
    component ACRTestACR,  [in: []], do: nil

    assert name(Dot.In.Name) == "Name"
    assert name(SimpleName) == "Simple Name"
    assert name(ACRTestACR) == "ACR Test ACR"
  end

  test "if descriptions work as they should" do
    component EmptyDescription, in: [:in], out: [] do
    end
    component NormalDescription, in: [:in], out: [] do
      "Description"
    end
    component WithExpression, in: [:in], out: [] do
      "Description"
      5 + 2
    end
    component MultilineDescription, in: [:in], out: [] do
      """
      Description
      """
    end

    assert description(EmptyDescription) == ""
    assert description(NormalDescription) == "Description"
    assert description(WithExpression) == "Description"
    assert String.trim(description(MultilineDescription)) == "Description"
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
      init a, b, do: instance a * b
    end

    assert TestInit.__skitter_init__([3, 4]) == {:ok, 3 * 4}
  end

  test "if helpers work" do
    component TestHelper, in: [] do
      init do: instance worker()

      helper worker do
        :from_helper
      end
    end

    assert TestHelper.__skitter_init__([]) == {:ok, :from_helper}
  end

  test "if effect errors are reported" do
    # be sure to test incorrect effect properties here once we use them.
    assert_definition_error do
      component WrongEffects, in: [] do
        effect does_not_exist
      end
    end
  end

  test "if port errors are reported" do
    assert_definition_error do
      component WrongInPorts, in: [:a,:b,:c] do
        react a, b do
        end
      end
    end

    assert_definition_error do
      component WrongSpit, in: [], out: [:foo] do
        react do
          spit :bar, 42
        end
      end
    end
  end
end
