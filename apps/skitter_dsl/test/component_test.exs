# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.ComponentTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions

  alias Skitter.{Component, Callback, Callback.Result, Strategy}

  import Skitter.DSL.Component
  doctest Skitter.DSL.Component

  def test_strategy do
    Skitter.DSL.Test.Strategy.get()
  end

  test "name extraction" do
    defcomponent testname do
      strategy test_strategy()
    end

    assert testname.name == "testname"
  end

  test "port extraction" do
    comp =
      component in: foo, out: bar do
        strategy test_strategy()
      end

    assert comp.in_ports == [:foo]
    assert comp.out_ports == [:bar]

    comp =
      component in: foo, out: bar do
        strategy test_strategy()
      end

    assert comp.in_ports == [:foo]
    assert comp.out_ports == [:bar]
  end

  test "fields extraction" do
    comp =
      component in: [] do
        strategy test_strategy()
        fields a, b, c
      end

    assert comp.fields == [:a, :b, :c]
  end

  test "inline strategy extraction" do
    comp =
      component in: [] do
        strategy %Strategy{
          name: Foo,
          define: %Callback{function: fn _, [component] -> %Result{result: component} end},
          deploy: :todo,
          prepare: :todo,
          send_token: :todo,
          receive_token: :todo,
          receive_message: :todo,
          drop_deployment: :todo,
          drop_invocation: :todo
        }
      end

    assert comp.strategy.name == Foo
  end

  test "callback extraction" do
    comp =
      component in: [] do
        strategy test_strategy()

        react _ do
        end
      end

    assert Map.has_key?(comp.callbacks, :react)
  end

  test "callback with multiple clauses" do
    comp =
      component in: [] do
        strategy test_strategy()

        cb :foo do
          :bar
        end

        cb x do
          x
        end
      end

    assert Component.call(comp, :cb, %{}, [10]).result == 10
    assert Component.call(comp, :cb, %{}, [:foo]).result == :bar
  end

  test "reuse directives" do
    comp =
      component in: [pid] do
        strategy test_strategy()

        require Integer
        import String, only: [to_integer: 1]
        alias String, as: S

        cb pid do
          send(pid, {:import, to_integer("1")})
          send(pid, {:alias, S.to_integer("2")})
          send(pid, {:require, Integer.is_odd(3)})
        end
      end

    Component.call(comp, :cb, %{}, [self()])

    assert_receive {:import, 1}
    assert_receive {:alias, 2}
    assert_receive {:require, true}
  end

  test "errors" do
    assert_definition_error ~r/.*: Invalid syntax: `:foo`/ do
      component([in: :foo], do: strategy(test_strategy()))
    end

    assert_definition_error ~r/.*: Invalid syntax: `5`/ do
      component in: [] do
        strategy test_strategy()
        fields a, b, 5
      end
    end

    assert_definition_error ~r/.*: Invalid port list: `.*`/ do
      component extra: foo do
        strategy test_strategy()
      end
    end

    assert_definition_error ~r/.*: Only one fields declaration is allowed: `.*`/ do
      component in: [] do
        strategy test_strategy()
        fields a, b, c
        fields x, y, z
      end
    end

    assert_definition_error ~r/.*: Missing strategy/ do
      component in: [] do
      end
    end

    assert_definition_error ~r/.*: Only one strategy declaration is allowed: `.*`/ do
      component in: [] do
        strategy Strategy1
        strategy Strategy2
      end
    end

    assert_definition_error ~r/`.*` is not a valid strategy/ do
      component in: [] do
        strategy 5
      end
    end

    assert_definition_error ~r/`.*` is not complete/ do
      component in: [] do
        strategy %Skitter.Strategy{}
      end
    end
  end
end
