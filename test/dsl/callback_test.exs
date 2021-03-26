# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.CallbackTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions

  alias Skitter.Callback
  alias Skitter.Callback.{Result, Info}

  doctest Skitter.DSL.Callback

  test "different arities" do
    defmodule Arity do
      use Skitter.DSL.Callback

      defcb f(), do: nil
      defcb f(arg1), do: arg1
      defcb f(_arg1, arg2), do: arg2
    end

    assert Callback.info(Arity, :f, 0) == %Info{read: [], write: [], publish: []}
    assert Callback.info(Arity, :f, 1) == %Info{read: [], write: [], publish: []}
    assert Callback.info(Arity, :f, 2) == %Info{read: [], write: [], publish: []}

    assert Callback.call(Arity, :f, %{}, []) == %Result{result: nil, state: %{}, publish: []}
    assert Callback.call(Arity, :f, %{}, [1]) == %Result{result: 1, state: %{}, publish: []}
    assert Callback.call(Arity, :f, %{}, [1, 2]) == %Result{result: 2, state: %{}, publish: []}
  end

  test "multiple clauses" do
    defmodule Clauses do
      use Skitter.DSL.Callback

      defcb f(:foo), do: x <~ :foo
      defcb f(:bar), do: y <~ :bar
      defcb f(:baz), do: :baz ~> z
    end

    assert Callback.info(Clauses, :f, 1) == %Info{read: [], write: [:y, :x], publish: [:z]}

    assert Callback.call(Clauses, :f, %{x: nil}, [:foo]) == %Result{
             result: :foo,
             state: %{x: :foo},
             publish: []
           }

    assert Callback.call(Clauses, :f, %{y: nil}, [:bar]) == %Result{
             result: :bar,
             state: %{y: :bar},
             publish: []
           }

    assert Callback.call(Clauses, :f, %{}, [:baz]) == %Result{
             result: :baz,
             state: %{},
             publish: [z: :baz]
           }
  end

  describe "if rewrite" do
    test "does not influence normal ifs" do
      defmodule NormalIf do
        use Skitter.DSL.Callback

        defcb test1() do
          if true, do: 10
        end

        defcb test2() do
          if true, do: 10, else: 20
        end

        defcb test3() do
          if false, do: 10, else: 20
        end
      end

      assert Callback.call(NormalIf, :test1, %{}, []).result == 10
      assert Callback.call(NormalIf, :test2, %{}, []).result == 10
      assert Callback.call(NormalIf, :test3, %{}, []).result == 20
    end

    test "allows state and publish updates" do
      defmodule StateIf do
        use Skitter.DSL.Callback

        defcb publish(arg) do
          if arg do
            :foo ~> true_port
          else
            :foo ~> false_port
          end
        end

        defcb state() do
          if ~f{x} do
            y <~ :foo
          else
            y <~ :bar
          end
        end
      end

      assert Callback.call(StateIf, :publish, %{}, [true]).publish == [true_port: :foo]
      assert Callback.call(StateIf, :publish, %{}, [false]).publish == [false_port: :foo]

      assert Callback.call(StateIf, :state, %{x: true, y: nil}, []).state == %{x: true, y: :foo}
      assert Callback.call(StateIf, :state, %{x: false, y: nil}, []).state == %{x: false, y: :bar}
    end

    test "throws when fields are incompatible" do
      assert_definition_error ~r/Incompatible writes in control structure..*/ do
        defmodule ErrorIf do
          use Skitter.DSL.Callback

          defcb test() do
            if true do
              x <~ :foo
            else
              y <~ :bar
            end
          end
        end
      end
    end
  end

  describe "case rewrite" do
    test "does not influece normal case" do
      defmodule NormalCase do
        use Skitter.DSL.Callback

        defcb test() do
          case 5 do
            5 -> 10
          end
        end
      end

      assert Callback.call(NormalCase, :test, %{}, []).result == 10
    end

    test "can update state" do
      defmodule StateCase do
        use Skitter.DSL.Callback

        defcb test() do
          case 5 do
            5 ->
              x <~ 10
          end
        end
      end

      assert Callback.call(StateCase, :test, %{x: 0}, []).state == %{x: 10}
    end

    test "can publish" do
      defmodule PublishCase do
        use Skitter.DSL.Callback

        defcb test(arg) do
          case arg do
            1 -> :foo ~> out
            2 -> :bar ~> other
          end
        end
      end

      assert Callback.call(PublishCase, :test, %{}, [1]).publish == [out: :foo]
      assert Callback.call(PublishCase, :test, %{}, [2]).publish == [other: :bar]
    end

    test "throws when fields are incompatible" do
      assert_definition_error ~r/Incompatible writes in control structure..*/ do
        defmodule ErrorCase do
          use Skitter.DSL.Callback

          defcb test() do
            case arg do
              1 -> x <~ 1
              2 -> y <~ 2
            end
          end
        end
      end
    end
  end
end
