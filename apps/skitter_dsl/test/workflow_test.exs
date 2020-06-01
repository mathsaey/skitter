# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.WorkflowTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions
  import Skitter.DSL.{Component, Workflow}

  alias Skitter.{Component, Instance, Callback, Callback.Result}
  alias Skitter.DSL.Registry

  doctest Skitter.DSL.Workflow

  setup_all do
    c =
      defcomponent __MODULE__.Dummy, in: [a, b, c], out: [x, y, z] do
        strategy DummyStrategy
      end

    [component: c]
  end

  test "name registration" do
    w =
      defworkflow __MODULE__.Named, in: ignore do
        strategy DummyStrategy
      end

    assert Registry.get(__MODULE__.Named) == w
  end

  test "inline strategy extraction" do
    w =
      defworkflow in: ignore do
        strategy %Component{
          name: Foo,
          callbacks: %{
            on_define: %Callback{
              function: fn _, [c] -> %Result{publish: [on_define: c]} end
            }
          }
        }
      end

    assert w.strategy.name == Foo
  end

  test "named strategy extraction" do
    strategy =
      %Component{
        name: __MODULE__.NamedStrategy,
        callbacks: %{
          on_define: %Callback{
            function: fn _, [c] -> %Result{publish: [on_define: c]} end
          }
        }
      }
      |> Registry.put_if_named()

    w =
      defworkflow in: ignore do
        strategy __MODULE__.NamedStrategy
      end

    assert w.strategy == strategy
  end

  test "module strategy extraction" do
    w =
      defworkflow in: ignore do
        strategy DummyStrategy
      end

    assert w.strategy == DummyStrategy
  end

  test "inline components", %{component: c} do
    w =
      defworkflow in: ignore do
        strategy DummyStrategy

        a = new(c)

        b =
          new(
            defcomponent in: ignore do
              strategy DummyStrategy
            end
          )
      end

    assert w[:a] == %Instance{elem: c, args: []}

    assert w[:b] == %Instance{
             elem: %Component{in_ports: [:ignore], strategy: DummyStrategy},
             args: []
           }
  end

  test "named components", %{component: c} do
    w =
      defworkflow in: ignore do
        strategy DummyStrategy
        c = new(c.name)
      end

    assert w[:c] == %Instance{elem: Registry.get(c.name), args: []}
  end

  test "links", %{component: c} do
    w =
      defworkflow in: [a, b, c], out: [x, y, z] do
        strategy DummyStrategy

        a = new(c)
        b = new(c)
        c = new(c)

        a ~> a.a
        a ~> a.b
        b ~> a.c

        a.x ~> b.a
        a.x ~> b.b

        b.x ~> x
        b.y ~> y
      end

    assert w.links == %{
             {nil, :a} => [{:a, :b}, {:a, :a}],
             {nil, :b} => [{:a, :c}],
             {:a, :x} => [b: :b, b: :a],
             {:b, :x} => [nil: :x],
             {:b, :y} => [nil: :y]
           }
  end

  test "errors", %{component: c} do
    assert_definition_error ~r/.*: Invalid syntax: `.*`/ do
      defworkflow in: ignore do
        strategy DummyStrategy

        a = instance Foo
      end
    end

    assert_definition_error ~r/.*: Invalid port list: `.*`/ do
      defworkflow extra: ignore do
        strategy DummyStrategy
      end
    end

    assert_definition_error ~r/.*: Missing strategy/ do
      defworkflow in: [] do
      end
    end

    assert_definition_error ~r/.*: Only one strategy declaration is allowed: `.*`/ do
      defworkflow in: ignore do
        strategy Foo
        strategy Bar
      end
    end

    assert_definition_error ~r/.*: `.*` is not allowed in a workflow/ do
      defworkflow in: ignore do
        strategy DummyStrategy
        5 + 2
      end
    end

    assert_definition_error ~r/`.*` is not defined/ do
      defworkflow in: ignore do
        strategy DummyStrategy

        _ = new(DoesNotExist)
      end
    end

    assert_definition_error ~r/`.*` is not a valid workflow port/ do
      defworkflow in: ignore do
        strategy DummyStrategy

        c = new(c.name)
        doesnotexist ~> c.a
      end
    end

    assert_definition_error ~r/`.*` is not a valid workflow port/ do
      defworkflow in: ignore do
        strategy DummyStrategy

        c = new(c.name)
        c.x ~> doesnotexist
      end
    end

    assert_definition_error ~r/`.*` does not exist/ do
      defworkflow in: ignore do
        strategy DummyStrategy

        ignore ~> doesnotexist.in_port
      end
    end

    assert_definition_error ~r/`.*` is not a port of `.*`/ do
      defworkflow in: ignore do
        strategy DummyStrategy

        c = new(c.name)
        ignore ~> c.in_port
      end
    end
  end
end
