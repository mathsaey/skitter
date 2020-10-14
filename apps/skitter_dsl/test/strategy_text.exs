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
      defstrategy __MODULE__.ParentMissing do
        define _ do
          :parent
        end
      end

      child =
        defstrategy extends: __MODULE__.ParentMissing do
        end

      assert Callback.call(child.define, %{}, [:_]).result == :parent
    end

    test "does not override existing methods" do
      defstrategy __MODULE__.ParentNoReplace do
        define _ do
          :parent
        end
      end

      child =
        defstrategy extends: __MODULE__.ParentNoReplace do
          define _ do
            :child
          end
        end

      assert Callback.call(child.define, %{}, [:_]).result == :child
    end

    test "multiple parents" do
      defstrategy FirstParent do
        define _ do
          :first_parent
        end
      end

      defstrategy SecondParent do
        define _ do
          :second_parent
        end

        prepare do
          :second_parent
        end
      end

      child =
        defstrategy extends: [FirstParent, SecondParent] do
        end

      assert Callback.call(child.define, %{}, [:_]).result == :first_parent
      assert Callback.call(child.prepare, %{}, []).result == :second_parent
    end

    test "inline parents" do
      parent =
        defstrategy do
          define _ do
            :parent
          end
        end

      child =
        defstrategy extends: parent do
        end

      assert Callback.call(child.define, %{}, [:_]).result == :parent
    end
  end

  test "errors" do
    assert_definition_error ~r/`.*` is not a valid strategy/ do
      defstrategy extends: 5 do
      end
    end

    assert_definition_error ~r/`.*` is not a valid strategy/ do
      import Skitter.DSL.Component

      defcomponent __MODULE__.Foo do
        strategy TestStrategy
      end

      defstrategy extends: __MODULE__.Foo do
      end
    end
  end
end
