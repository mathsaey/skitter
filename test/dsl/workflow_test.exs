# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.WorkflowTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions
  import Skitter.DSL.{Component, Workflow}

  alias Skitter.Component

  doctest Skitter.DSL.Workflow

  def test_strategy do
    Skitter.Test.Strategy.get()
  end

  def test_component do
    component in: [a, b, c], out: [x, y, z] do
      strategy test_strategy()
    end
  end

  test "name extraction" do
    defworkflow testworkflow do
    end

    assert testworkflow.name == "testworkflow"
  end

  test "port extraction" do
    wf =
      workflow in: foo, out: bar do
      end

    assert wf.in == [:foo]
    assert wf.out == [:bar]

    wf =
      workflow in: foo, out: bar do
      end

    assert wf.in == [:foo]
    assert wf.out == [:bar]
  end

  test "inline components" do
    w =
      workflow in: ignore do
        a = new(test_component())

        b =
          new(
            component in: ignore do
              strategy test_strategy()
            end
          )
      end

    assert w[:a] == {test_component(), []}
    assert w[:b] == {%Component{in: [:ignore], strategy: test_strategy()}, []}
  end

  test "links" do
    w =
      workflow in: [a, b, c], out: [x, y, z] do
        a = new(test_component())
        b = new(test_component())
        c = new(test_component())

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

  test "errors" do
    assert_definition_error ~r/.*: Invalid syntax: `.*`/ do
      workflow in: ignore do
        a = instance Foo
      end
    end

    assert_definition_error ~r/.*: Invalid port list: `.*`/ do
      workflow extra: ignore do
      end
    end

    assert_definition_error ~r/.*: `.*` is not allowed in a workflow/ do
      workflow in: ignore do
        5 + 2
      end
    end

    assert_definition_error ~r/`.*` is not a valid component or workflow/ do
      workflow in: ignore do
        _ = new(5)
      end
    end

    assert_definition_error ~r/`.*` is not a valid workflow port/ do
      workflow in: ignore do
        c = new(test_component())
        doesnotexist ~> c.a
      end
    end

    assert_definition_error ~r/`.*` is not a valid workflow port/ do
      workflow in: ignore do
        c = new(test_component())
        c.x ~> doesnotexist
      end
    end

    assert_definition_error ~r/`.*` does not exist/ do
      workflow in: ignore do
        ignore ~> doesnotexist.in_port
      end
    end

    assert_definition_error ~r/`.*` is not a port of `.*`/ do
      workflow in: ignore do
        c = new(test_component())
        ignore ~> c.in_port
      end
    end
  end
end
