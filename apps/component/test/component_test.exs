defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.Component

  # ----- #
  # Tests #
  # ----- #

  doctest Skitter.Component

  test "if names are generated correctly" do
    component Dot.In.Name, [in: [], out: []], do: nil
    component SimpleName,  [in: [], out: []], do: nil
    component ACRTestACR,  [in: [], out: []], do: nil

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
end
