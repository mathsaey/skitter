# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.StrategyTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions

  alias Skitter.Callback

  import Skitter.DSL.Strategy
  doctest Skitter.DSL.Strategy

  describe "extends" do
    test "replaces missing methods" do
      parent =
        strategy do
          define _ do
            :parent
          end
        end

      child =
        strategy extends: parent do
        end

      assert Callback.call(child.define, %{}, [:_]).result == :parent
    end

    test "does not override existing methods" do
      parent =
        strategy do
          define _ do
            :parent
          end
        end

      child =
        strategy extends: parent do
          define _ do
            :child
          end
        end

      assert Callback.call(child.define, %{}, [:_]).result == :child
    end

    test "multiple parents" do
      first_parent =
        strategy do
          define _ do
            :first_parent
          end
        end

      second_parent =
        strategy do
          define _ do
            :second_parent
          end

          prepare do
            :second_parent
          end
        end

      child =
        strategy extends: [first_parent, second_parent] do
        end

      assert Callback.call(child.define, %{}, [:_]).result == :first_parent
      assert Callback.call(child.prepare, %{}, []).result == :second_parent
    end
  end

  test "errors" do
    assert_definition_error ~r/`.*` is not a valid strategy/ do
      strategy extends: 5 do
      end
    end
  end
end
