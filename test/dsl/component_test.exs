# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.DSL.Component
  import Skitter.DSL.Test.Assertions

  defcomponent FieldsExample, strategy: Dummy do
    fields foo: 42
  end

  defcomponent NoFields, strategy: Dummy do
  end

  defcomponent Average, in: value, out: current, strategy: SomeStrategy do
    fields total: 0, count: 0

    defcb react(value) do
      total <~ (~f{total} + value)
      count <~ (~f{count} + 1)

      (~f{total} / ~f{count}) ~> current
    end
  end

  alias Skitter.{Component, Callback.Result}

  doctest Skitter.DSL.Component

  test "multiple fields results in error" do
    assert_definition_error ~r/.*: Only one fields declaration is allowed/ do
      defcomponent ShouldError, strategy: Dummy do
        fields a: 1
        fields b: 2
      end
    end
  end

  test "no strategy results in error" do
    assert_definition_error ~r/Missing strategy/ do
      defcomponent ShouldError do
      end
    end
  end

  test "invalid strategy results in error" do
    assert_definition_error ~r/Invalid strategy: `5`/ do
      defcomponent ShouldError, strategy: 5 do
      end
    end
  end
end
