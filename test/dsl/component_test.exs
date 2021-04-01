# Copyright 2018 - 2021 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.DSL.{Component, Strategy}
  import Skitter.DSL.Test.Assertions

  alias Skitter.Component
  alias Skitter.Component.Callback.{Info, Result}

  defcomponent FieldsExample, strategy: Dummy do
    fields foo: 42
  end

  defcomponent NoFields, strategy: Dummy do
  end

  defcomponent Average, in: value, out: current, strategy: Dummy do
    fields total: 0, count: 0

    defcb react(value) do
      total <~ (~f{total} + value)
      count <~ (~f{count} + 1)

      (~f{total} / ~f{count}) ~> current
    end
  end

  defcomponent ReadExample, strategy: Dummy do
    fields [:field]
    defcb read(), do: ~f{field}
  end

  defcomponent WriteExample, strategy: Dummy do
    fields [:field]
    defcb write(), do: field <~ :bar
  end

  defcomponent WrongWriteExample, strategy: Dummy do
    fields [:field]
    defcb write(), do: doesnotexist <~ :bar
  end

  defcomponent PublishExample, strategy: Dummy do
    defcb publish(value) do
      value ~> some_port
      :foo ~> some_other_port
    end
  end

  defcomponent CbExample, strategy: Dummy do
    defcb simple(), do: nil
    defcb arguments(arg1, arg2), do: arg1 + arg2
    defcb state(), do: counter <~ (~f{counter} + 1)
    defcb publish(), do: ~D[1991-12-08] ~> out_port
  end

  doctest Skitter.DSL.Component

  describe "defcomponent" do
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

  defcomponent Clauses, strategy: Dummy do
    fields [:x, :y]

    defcb f(:foo), do: x <~ :foo
    defcb f(:bar), do: y <~ :bar
    defcb f(:baz), do: :baz ~> z
  end

  test "multiple callback clauses" do
    assert Component.callback_info(Clauses, :f, 1) == %Info{
             read: [],
             write: [:y, :x],
             publish: [:z]
           }

    assert Component.call(Clauses, :f, [:foo]) == %Result{
             result: :foo,
             state: %Clauses{x: :foo, y: nil},
             publish: []
           }

    assert Component.call(Clauses, :f, [:bar]) == %Result{
             result: :bar,
             state: %Clauses{x: nil, y: :bar},
             publish: []
           }

    assert Component.call(Clauses, :f, [:baz]) == %Result{
             result: :baz,
             state: %Clauses{},
             publish: [z: :baz]
           }
  end

  describe "control flow rewrite" do
    test "if does not influence normal if" do
      defcomponent NormalIf, strategy: Dummy do
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

      assert Component.call(NormalIf, :test1, []).result == 10
      assert Component.call(NormalIf, :test2, []).result == 10
      assert Component.call(NormalIf, :test3, []).result == 20
    end

    test "if allows state and publish updates" do
      defcomponent StateIf, strategy: Dummy do
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

      assert Component.call(StateIf, :publish, [true]).publish == [true_port: :foo]
      assert Component.call(StateIf, :publish, [false]).publish == [false_port: :foo]

      assert Component.call(StateIf, :state, %{x: true, y: nil}, []).state == %{x: true, y: :foo}

      assert Component.call(StateIf, :state, %{x: false, y: nil}, []).state == %{
               x: false,
               y: :bar
             }
    end

    test "if throws when fields are incompatible" do
      assert_definition_error ~r/Incompatible writes in control structure..*/ do
        defcomponent ErrorIf, strategy: Dummy do
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

    test "case does not influece normal case" do
      defcomponent NormalCase, strategy: Dummy do
        defcb test() do
          case 5 do
            5 -> 10
          end
        end
      end

      assert Component.call(NormalCase, :test, []).result == 10
    end

    test "case can update state" do
      defcomponent StateCase, strategy: Dummy do
        defcb test() do
          case 5 do
            5 ->
              x <~ 10
          end
        end
      end

      assert Component.call(StateCase, :test, %{x: 0}, []).state == %{x: 10}
    end

    test "case can publish" do
      defcomponent PublishCase, strategy: Dummy do
        defcb test(arg) do
          case arg do
            1 -> :foo ~> out
            2 -> :bar ~> other
          end
        end
      end

      assert Component.call(PublishCase, :test, [1]).publish == [out: :foo]
      assert Component.call(PublishCase, :test, [2]).publish == [other: :bar]
    end

    test "case throws when fields are incompatible" do
      assert_definition_error ~r/Incompatible writes in control structure..*/ do
        defcomponent ErrorCase, strategy: Dummy do
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
