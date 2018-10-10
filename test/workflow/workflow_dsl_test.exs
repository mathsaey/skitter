# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.WorkflowDSLTest do
  use ExUnit.Case, async: true

  import Skitter.Component
  import Skitter.Assertions
  import Skitter.Workflow.DSL

  # -------------- #
  # Test Component #
  # -------------- #

  component Id, in: val, out: val do
    react v do
      v ~> val
    end
  end

  component MultiplePorts, in: [a, b], out: [x, y] do
    react _a, _b do
    end
  end

  # ----- #
  # Tests #
  # ----- #

  test "if sources are parsed correctly" do
    w = workflow do
      source a ~> x.val
      source b ~> {x.val, y.val}
      source c ~> {x.val, y.val, z.val}

      x = {Id, _}
      y = {Id, _}
      z = {Id, _}
    end

    %Skitter.Workflow{instances: _, sources: sources} = w
    assert sources == %{
      a: [x: :val],
      b: [x: :val, y: :val],
      c: [x: :val, y: :val, z: :val]
    }
  end

  test "if instances are parsed correctly" do
    w = workflow do
      source a ~> {x.a, x.b}

      x = {
        MultiplePorts, nil,
        x ~> x_dest.val,
        y ~> y_dest.a, y ~> y_dest.b, # Multiple destinations single out port
      }

      x_dest = {Id, nil}
      y_dest = {MultiplePorts, nil}
    end

    %Skitter.Workflow{instances: instances, sources: _} = w
    assert instances == %{
      x: {MultiplePorts, nil, [x: [x_dest: :val], y: [y_dest: :a, y_dest: :b]]},
      x_dest: {Id, nil, []},
      y_dest: {MultiplePorts, nil, []}
    }
  end

  test "if _ is correctly transformed into `nil`" do
    w1 = workflow do
      source a ~> b.val

      b = {Id, nil}
    end

    w2 = workflow do
      source a ~> b.val

      b = {Id, _}
    end

    assert w1 == w2
  end

  # Error Reporting
  # ---------------

  test "if incorrect syntax is reported" do
    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      workflow(do: {Id, nil})
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      workflow(do: a ~> b.c)
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      workflow(do: source a = {T, _})
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      workflow(do: source :a ~> b.c)
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      workflow(do: source a ~> b)
    end
  end

  test "if duplicate names are reported" do
    assert_definition_error ~r/Duplicate identifier in workflow: .*/ do
      workflow do
        source s ~> a.val
        source s ~> b.val

        a = {Id, _}
        b = {Id, _}
      end
    end

    assert_definition_error ~r/Duplicate identifier in workflow: .*/ do
      workflow do
        source s ~> i.val

        i = {Id, _}
        i = {Id, _}
      end
    end

    assert_definition_error ~r/Duplicate identifier in workflow: .*/ do
      workflow do
        source s ~> s.val
        s = {Id, _}
      end
    end
  end

  test "if missing modules are reported" do
    assert_definition_error ~r/`.*` does not exist or is not loaded/ do
      workflow do
        source s ~> i.val
        i = {DoesNotExist, nil}
      end
    end
  end

  test "if existing modules which are not a component are reported" do
    assert_definition_error ~r/`.*` is not a skitter component/ do
      workflow do
        source s ~> i.val
        i = {Enum, nil}
      end
    end
  end

  test "if links from wrong out ports are reported" do
    assert_definition_error ~r/`.*` is not a valid out port of `.*`/ do
      workflow do
        source s ~> i1.val

        i1 = {Id, _, x ~> i2.val}
        i2 = {Id, _}
      end
    end
  end

  test "if links to unknown names are reported" do
    assert_definition_error ~r/Unknown identifier: .*/ do
      workflow do
        source s ~> i.val
      end
    end

    assert_definition_error ~r/Unknown identifier: .*/ do
      workflow do
        source s ~> i.val
        i = {Id, _, val ~> x.val}
      end
    end
  end

  test "if unconnected in ports are reported" do
    assert_definition_error ~r/Unused in ports present in workflow: `.*`/ do
      workflow do
        i = {Id, _}
      end
    end
  end

  test "if links to wrong in ports are reported" do
    assert_definition_error ~r/`.*` is not a valid in port of `.*`/ do
      workflow do
        source s ~> i.data
        source _ ~> i.val

        i = {Id, _}
      end
    end
  end
end
