# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.WorkflowTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions
  import Skitter.DSL.{Component, Workflow}

  alias Skitter.{Component, Instance, Callback, Callback.Result}
  alias Skitter.DSL.Named

  doctest Skitter.DSL.Workflow

  setup_all do
    c =
      defcomponent __MODULE__.Dummy, in: [a, b, c], out: [x, y, z] do
        strategy TestStrategy
      end

    [component: c]
  end

  test "name extraction" do
    wf =
      defworkflow __MODULE__.TestName do
      end

    assert wf.name == __MODULE__.TestName

    wf =
      defworkflow __MODULE__.OtherTestName, in: foo, out: bar do
      end

    assert wf.name == __MODULE__.OtherTestName
  end

  test "port extraction" do
    wf =
      defworkflow __MODULE__.IgnoreThisName, in: foo, out: bar do
      end

    assert wf.in_ports == [:foo]
    assert wf.out_ports == [:bar]

    wf =
      defworkflow in: foo, out: bar do
      end

    assert wf.in_ports == [:foo]
    assert wf.out_ports == [:bar]
  end

  test "name registration" do
    w =
      defworkflow __MODULE__.Named, in: ignore do
      end

    assert Named.load(__MODULE__.Named) == w
  end

  test "inline components", %{component: c} do
    w =
      defworkflow in: ignore do
        a = new(c)

        b =
          new(
            defcomponent in: ignore do
              strategy TestStrategy
            end
          )
      end

    assert w[:a] == %Instance{elem: c, args: []}

    assert w[:b] == %Instance{
             elem: %Component{in_ports: [:ignore], strategy: Named.load(TestStrategy)},
             args: []
           }
  end

  test "named components", %{component: c} do
    w =
      defworkflow in: ignore do
        c = new(c.name)
      end

    assert w[:c] == %Instance{elem: Named.load(c.name), args: []}
  end

  test "links", %{component: c} do
    w =
      defworkflow in: [a, b, c], out: [x, y, z] do
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
        a = instance Foo
      end
    end

    assert_definition_error ~r/.*: Invalid port list: `.*`/ do
      defworkflow extra: ignore do
      end
    end

    assert_definition_error ~r/.*: `.*` is not allowed in a workflow/ do
      defworkflow in: ignore do
        5 + 2
      end
    end

    assert_definition_error ~r/`.*` is not defined/ do
      defworkflow in: ignore do
        _ = new(DoesNotExist)
      end
    end

    assert_definition_error ~r/`.*` is not a valid component or workflow/ do
      defworkflow in: ignore do
        _ = new(5)
      end
    end

    assert_definition_error ~r/`.*` is not a valid workflow port/ do
      defworkflow in: ignore do
        c = new(c.name)
        doesnotexist ~> c.a
      end
    end

    assert_definition_error ~r/`.*` is not a valid workflow port/ do
      defworkflow in: ignore do
        c = new(c.name)
        c.x ~> doesnotexist
      end
    end

    assert_definition_error ~r/`.*` does not exist/ do
      defworkflow in: ignore do
        ignore ~> doesnotexist.in_port
      end
    end

    assert_definition_error ~r/`.*` is not a port of `.*`/ do
      defworkflow in: ignore do
        c = new(c.name)
        ignore ~> c.in_port
      end
    end
  end
end
