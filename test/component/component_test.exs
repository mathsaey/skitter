# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true
  import Skitter.Test.Assertions

  alias Skitter.Component
  alias Skitter.Component.Callback

  import Skitter.Component
  doctest Skitter.Component

  describe "defcomponent" do
    test "fields extraction" do
      comp =
        defcomponent in: [] do
          fields a, b, c
        end

      assert comp.fields == [:a, :b, :c]
    end

    test "callback extraction in block" do
      comp =
        defcomponent in: [] do
          react _ do
          end
        end

      assert Map.has_key?(comp.callbacks, :react)
    end

    test "callback extraction without block" do
      comp = defcomponent([in: []], do: react(_, do: nil))
      assert Map.has_key?(comp.callbacks, :react)
    end
  end

  test "errors" do
    assert_definition_error ~r/.*: Invalid syntax: `foo`/ do
      defcomponent(Test, [in: :foo], do: nil)
    end

    assert_definition_error ~r/.*: Invalid port list: `.*`/ do
      defcomponent(Test, [extra: foo], do: nil)
    end

    assert_definition_error ~r/.*: Invalid field: `.*`/ do
      defcomponent(Test, [in: []], do: (fields a, b, 5))
    end

    assert_definition_error ~r/.*: Only one fields declaration is allowed: `.*`/ do
      defcomponent Test, in: [] do
        fields a, b, c
        fields x, y, z
      end
    end
  end
end
