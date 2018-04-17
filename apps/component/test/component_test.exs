defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.Component

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
    component EffectTest, in: [] do
      effect internal_state p1, p2
      effect external_effects #no properties
    end

    assert EffectTest |> effects() |> Keyword.get(:internal_state) == [:p1, :p2]
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
end
