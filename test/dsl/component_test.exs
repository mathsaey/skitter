# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

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
    initial_state 0
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

  defcomponent ConfigExample do
    defcb read(), do: config()
  end

  defcomponent ReadExample do
    initial_state 0
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

  defcomponent TryExample do
    defcb simple(fun) do
      try do
        pre <~ :modified
        res = fun.()
        post <~ :modified
        :emit ~> out
        res
      rescue
        RuntimeError ->
          x <~ :modified
          :rescue
      catch
        _ ->
          :emit ~> out
          :catch
      end
    end

    defcb with_else(fun) do
      try do
        pre <~ :modified
        res = fun.()
        post <~ :modified
        :emit ~> out
        res
      rescue
        RuntimeError ->
          :rescue
      else
        res ->
          x <~ :modified
          res
      end
    end

    defcb with_after(fun) do
      try do
        pre <~ :modified
        res = fun.()
        post <~ :modified
        :emit ~> out
        res
      rescue
        RuntimeError -> :rescue
      after
        x <~ :modified
        :ignored
      end
    end
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

    defcb g(x) when x > 5, do: :gt
    defcb g(x) when x < 5, do: :lt
    defcb g(_), do: :eq
  end

  test "multiple callback clauses" do
    assert Component.callback_info(Clauses, :f, 1) == %Info{
             read?: false,
             write?: true,
             emit?: true
           }

    assert Component.call(Clauses, :f, [:foo]) == %Result{
             result: nil,
             state: %Clauses{x: :foo, y: nil},
             emit: []
           }

    assert Component.call(Clauses, :f, [:bar]) == %Result{
             result: nil,
             state: %Clauses{x: nil, y: :bar},
             emit: []
           }

    assert Component.call(Clauses, :f, [:baz]) == %Result{
             result: nil,
             state: %Clauses{},
             emit: [z: [:baz]]
           }
  end

  test "guards" do
    assert Component.call(Clauses, :g, [0]).result == :lt
    assert Component.call(Clauses, :g, [8]).result == :gt
    assert Component.call(Clauses, :g, [5]).result == :eq
  end

  describe "control flow rewrite" do
    test "if without updates" do
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

    test "if with state and emit updates" do
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

      assert Component.call(StateIf, :state, %{x: true, y: nil}, nil, []).state == %{
               x: true,
               y: :foo
             }

      assert Component.call(StateIf, :state, %{x: false, y: nil}, nil, []).state == %{
               x: false,
               y: :bar
             }
    end

    test "case without updates" do
      defcomponent NormalCase do
        defcb test() do
          case 5 do
            5 -> 10
          end
        end
      end

      assert Component.call(NormalCase, :test, []).result == 10
    end

    test "case with state update" do
      defcomponent StateCase do
        defcb test() do
          case 5 do
            5 ->
              x <~ 10
          end
        end
      end

      assert Component.call(StateCase, :test, %{x: 0}, nil, []).state == %{x: 10}
    end

    test "case with emit" do
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

    test "cond without updates" do
      defcomponent NormalCond do
        defcb test(arg_1, arg_2) do
          cond do
            arg_1 -> :arg_1
            arg_2 -> :arg_2
            true -> :else
          end
        end
      end

      assert Component.call(NormalCond, :test, [true, true]).result == :arg_1
      assert Component.call(NormalCond, :test, [false, true]).result == :arg_2
      assert Component.call(NormalCond, :test, [false, false]).result == :else
    end

    test "cond" do
      defcomponent RewriteCond do
        defcb test(state, emit, both) do
          cond do
            state ->
              x <~ :modified
              :state

            emit ->
              :emit ~> out
              :emit

            both ->
              x <~ :modified
              :emit ~> out
              :both

            true ->
              :else
          end
        end
      end

      assert Component.call(RewriteCond, :test, %{x: :unchanged}, nil, [true, true, true]) ==
               %Result{emit: [], state: %{x: :modified}, result: :state}

      assert Component.call(RewriteCond, :test, %{x: :unchanged}, nil, [false, true, true]) ==
               %Result{emit: [out: [:emit]], state: %{x: :unchanged}, result: :emit}

      assert Component.call(RewriteCond, :test, %{x: :unchanged}, nil, [false, false, true]) ==
               %Result{emit: [out: [:emit]], state: %{x: :modified}, result: :both}

      assert Component.call(RewriteCond, :test, %{x: :unchanged}, nil, [false, false, false]) ==
               %Result{emit: [], state: %{x: :unchanged}, result: :else}
    end

    test "receive without updates" do
      defcomponent NormalReceive do
        defcb test do
          receive do
            :foo -> :bar
          end
        end
      end

      send(self(), :foo)
      assert Component.call(NormalReceive, :test, []).result == :bar
    end

    test "receive" do
      defcomponent RewriteReceive do
        defcb test do
          receive do
            :foo ->
              :bar

            :state ->
              x <~ :modified
              :state

            :emit ->
              :emit ~> out
              :emit

            :both ->
              x <~ :modified
              :emit ~> out
              :both
          end
        end
      end

      send(self(), :foo)

      assert Component.call(RewriteReceive, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [],
               state: %{x: :unchanged},
               result: :bar
             }

      send(self(), :state)

      assert Component.call(RewriteReceive, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [],
               state: %{x: :modified},
               result: :state
             }

      send(self(), :emit)

      assert Component.call(RewriteReceive, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [out: [:emit]],
               state: %{x: :unchanged},
               result: :emit
             }

      send(self(), :both)

      assert Component.call(RewriteReceive, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [out: [:emit]],
               state: %{x: :modified},
               result: :both
             }
    end

    test "receive with after without updates" do
      defcomponent NormalReceiveAfter do
        defcb test do
          receive do
            :foo -> :bar
          after
            0 -> :none
          end
        end
      end

      send(self(), :foo)
      assert Component.call(NormalReceiveAfter, :test, []).result == :bar
      assert Component.call(NormalReceiveAfter, :test, []).result == :none
    end

    test "receive with after" do
      defcomponent RewriteReceiveAfter do
        defcb test do
          receive do
            :foo ->
              :bar

            :state ->
              x <~ :modified
              :state

            :emit ->
              :emit ~> out
              :emit

            :both ->
              x <~ :modified
              :emit ~> out
              :both
          after
            0 ->
              x <~ :modified
              :emit ~> out
              :none
          end
        end
      end

      send(self(), :foo)

      assert Component.call(RewriteReceiveAfter, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [],
               state: %{x: :unchanged},
               result: :bar
             }

      send(self(), :state)

      assert Component.call(RewriteReceiveAfter, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [],
               state: %{x: :modified},
               result: :state
             }

      send(self(), :emit)

      assert Component.call(RewriteReceiveAfter, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [out: [:emit]],
               state: %{x: :unchanged},
               result: :emit
             }

      send(self(), :both)

      assert Component.call(RewriteReceiveAfter, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [out: [:emit]],
               state: %{x: :modified},
               result: :both
             }

      assert Component.call(RewriteReceiveAfter, :test, %{x: :unchanged}, nil, []) == %Result{
               emit: [out: [:emit]],
               state: %{x: :modified},
               result: :none
             }
    end

    test "try without updates" do
      defcomponent NormalTry do
        defcb test(fun) do
          try do
            fun.()
          rescue
            RuntimeError ->
              :rescue
          catch
            _ ->
              :catch
          else
            x when x in [:foo, :bar] ->
              :baz

            _ ->
              :else
          after
            :ignored
          end
        end
      end

      assert Component.call(NormalTry, :test, [fn -> raise RuntimeError end]).result == :rescue
      assert Component.call(NormalTry, :test, [fn -> throw(:foo) end]).result == :catch
      assert Component.call(NormalTry, :test, [fn -> :ok end]).result == :else
    end
  end
end
