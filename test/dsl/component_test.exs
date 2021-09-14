# Copyright 2018 - 2021 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.ComponentTest do
  use ExUnit.Case, async: true

  import Skitter.DSL.Component
  import Skitter.DSL.Test.Assertions

  alias Skitter.Component
  alias Skitter.Component.Callback.{Info, Result}

  defcomponent NoStateExample do
    defcb return_state, do: state()
  end

  defcomponent StateExample do
    state 0
    defcb return_state, do: state()
  end

  defcomponent Average, in: value, out: current do
    state_struct total: 0, count: 0

    defcb react(val) do
      count <~ (~f{count} + 1)
      total <~ (~f{total} + val)
      (~f{total} / ~f{count}) ~> current
    end
  end

  defcomponent ReadExample do
    state 0
    defcb read(), do: state()
  end

  defcomponent FieldReadExample do
    state_struct field: nil
    defcb read(), do: ~f{field}
  end

  defcomponent WriteExample do
    defcb write(), do: state <~ :foo
  end

  defcomponent FieldWriteExample do
    state_struct [:field]
    defcb write(), do: field <~ :bar
  end

  defcomponent WrongFieldWriteExample do
    state_struct [:field]
    defcb write(), do: doesnotexist <~ :bar
  end

  defcomponent SingleEmitExample do
    defcb emit(value) do
      value ~> some_port
      :foo ~> some_other_port
    end
  end

  defcomponent MultiEmitExample do
    defcb emit(value) do
      value ~> some_port
      [:foo, :bar] ~>> some_other_port
    end
  end

  defcomponent CbExample do
    defcb simple(), do: nil
    defcb arguments(arg1, arg2), do: arg1 + arg2
    defcb state(), do: counter <~ (~f{counter} + 1)
    defcb emit_single(), do: ~D[1991-12-08] ~> out_port
    defcb emit_multi(), do: [~D[1991-12-08], ~D[2021-07-08]] ~>> out_port
  end

  doctest Skitter.DSL.Component

  describe "defcomponent" do
    test "invalid strategy results in error" do
      assert_definition_error ~r/Invalid strategy: `5`/ do
        defcomponent ShouldError, strategy: 5 do
        end
      end
    end
  end

  defcomponent Clauses do
    state_struct [:x, :y]

    defcb f(:foo), do: x <~ :foo
    defcb f(:bar), do: y <~ :bar
    defcb f(:baz), do: :baz ~> z
  end

  test "multiple callback clauses" do
    assert Component.callback_info(Clauses, :f, 1) == %Info{
             read?: false,
             write?: true,
             emit?: true
           }

    assert Component.call(Clauses, :f, [:foo]) == %Result{
             result: %Clauses{x: :foo, y: nil},
             state: %Clauses{x: :foo, y: nil},
             emit: []
           }

    assert Component.call(Clauses, :f, [:bar]) == %Result{
             result: %Clauses{x: nil, y: :bar},
             state: %Clauses{x: nil, y: :bar},
             emit: []
           }

    assert Component.call(Clauses, :f, [:baz]) == %Result{
             result: :baz,
             state: %Clauses{},
             emit: [z: [:baz]]
           }
  end

  describe "control flow rewrite" do
    test "if does not influence normal if" do
      defcomponent NormalIf do
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

    test "if allows state and emit updates" do
      defcomponent StateIf do
        defcb emit(arg) do
          if arg do
            :foo ~> true_port
            [:bar, :baz] ~>> true_multi
          else
            :foo ~> false_port
            [:bar, :baz] ~>> false_multi
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

      assert Component.call(StateIf, :emit, [true]).emit == [
               true_multi: [:bar, :baz],
               true_port: [:foo]
             ]

      assert Component.call(StateIf, :emit, [false]).emit == [
               false_multi: [:bar, :baz],
               false_port: [:foo]
             ]

      assert Component.call(StateIf, :state, %{x: true, y: nil}, []).state == %{x: true, y: :foo}

      assert Component.call(StateIf, :state, %{x: false, y: nil}, []).state == %{
               x: false,
               y: :bar
             }
    end

    test "case does not influence normal case" do
      defcomponent NormalCase do
        defcb test() do
          case 5 do
            5 -> 10
          end
        end
      end

      assert Component.call(NormalCase, :test, []).result == 10
    end

    test "case can update state" do
      defcomponent StateCase do
        defcb test() do
          case 5 do
            5 ->
              x <~ 10
          end
        end
      end

      assert Component.call(StateCase, :test, %{x: 0}, []).state == %{x: 10}
    end

    test "case can emit" do
      defcomponent EmitCase do
        defcb test(arg) do
          case arg do
            1 -> :foo ~> out
            2 -> [:bar, :baz] ~>> other
          end
        end
      end

      assert Component.call(EmitCase, :test, [1]).emit == [out: [:foo]]
      assert Component.call(EmitCase, :test, [2]).emit == [other: [:bar, :baz]]
    end
  end
end
