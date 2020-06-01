# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.ComponentTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions

  alias Skitter.{Component, Callback, Callback.Result}
  alias Skitter.DSL.Registry

  import Skitter.DSL.Component
  doctest Skitter.DSL.Component

  test "fields extraction" do
    comp =
      defcomponent in: [] do
        strategy DummyStrategy
        fields a, b, c
      end

    assert comp.fields == [:a, :b, :c]
  end

  test "inline strategy extraction" do
    comp =
      defcomponent in: [] do
        strategy %Component{
          name: Foo,
          callbacks: %{
            on_define: %Callback{
              function: fn _, [c] -> %Result{publish: [on_define: c]} end
            }
          }
        }
      end

    assert comp.strategy.name == Foo
  end

  test "named strategy extraction" do
    strategy = %Component{
      name: __MODULE__.NamedStrategy,
      callbacks: %{
        on_define: %Callback{
          function: fn _, [c] -> %Result{publish: [on_define: c]} end
        }
      }
    }
    |> Registry.put_if_named()

    comp =
      defcomponent nil, in: [] do
        strategy __MODULE__.NamedStrategy
      end

    assert comp.strategy == strategy
  end

  test "module strategy extraction" do
    comp =
      defcomponent in: [] do
        strategy DummyStrategy
      end

    assert comp.strategy == DummyStrategy
  end

  test "callback extraction" do
    comp =
      defcomponent in: [] do
        strategy DummyStrategy

        react _ do
        end
      end

    assert Map.has_key?(comp.callbacks, :react)
  end

  test "reuse directives" do
    comp =
      defcomponent in: [pid] do
        strategy DummyStrategy

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

  test "name registration" do
    c =
      defcomponent(__MODULE__.Named, [in: ignore], do: strategy(DummyStrategy))

    assert Registry.get(__MODULE__.Named) == c
  end

  test "errors" do
    assert_definition_error ~r/.*: Invalid syntax: `:foo`/ do
      defcomponent(Test, [in: :foo], do: strategy(DummyStrategy))
    end

    assert_definition_error ~r/.*: Invalid syntax: `5`/ do
      defcomponent Test, in: [] do
        strategy DummyStrategy
        fields a, b, 5
      end
    end

    assert_definition_error ~r/.*: Invalid port list: `.*`/ do
      defcomponent Test, extra: foo do
        strategy DummyStrategy
      end
    end

    assert_definition_error ~r/.*: Only one fields declaration is allowed: `.*`/ do
      defcomponent Test, in: [] do
        strategy DummyStrategy
        fields a, b, c
        fields x, y, z
      end
    end

    assert_definition_error ~r/.*: Missing strategy/ do
      defcomponent in: [] do
      end
    end

    assert_definition_error ~r/.*: Only one strategy declaration is allowed: `.*`/ do
      defcomponent in: [] do
        strategy Strategy1
        strategy Strategy2
      end
    end

    assert_definition_error ~r/`.*` is not a valid component or module name/ do
      defcomponent in: [] do
        strategy DoesNotExist
      end
    end

    assert_definition_error ~r/`.*` is not a valid component strategy/ do
      defcomponent in: [] do
        strategy 5
      end
    end
  end
end
