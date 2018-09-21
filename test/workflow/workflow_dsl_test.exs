# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.WorkflowDSLTest do
  use ExUnit.Case, async: true

  import Skitter.Component
  import Skitter.Assertions
  import Skitter.Workflow.DSL

  alias Workflow, as: WF
  alias Skitter.Workflow.Source, as: SrcAlias

  # -------------- #
  # Test Component #
  # -------------- #

  component NoPorts, in: [], out: [] do
    react do
    end
  end

  component Foo, in: [a, b], out: [c, d] do
    react _a, _b do
    end
  end

  # ----- #
  # Tests #
  # ----- #

  test "if blocks and single statements are handled correctly" do
    t1 = workflow(do: _ = {Source, nil})

    t2 =
      workflow do
        _ = {Source, nil}
        i = {NoPorts, nil}
      end

    assert t1 == %WF{map: %{_: {SrcAlias, nil, []}}}
    assert t2 == %WF{map: %{_: {SrcAlias, nil, []}, i: {NoPorts, nil, []}}}
  end

  test "if both triple and double element tuples are handled correctly" do
    t =
      workflow do
        _ = {Source, nil}
        triple = {Foo, nil, c ~> triple.a, d ~> triple.b}
      end

    assert t == %WF{map: %{
             _: {SrcAlias, nil, []},
             triple: {Foo, nil, [c: [{:triple, :a}], d: [{:triple, :b}]]}
           }}
  end

  test "if links and names are parsed correctly" do
    t =
      workflow do
        _ = {Source, nil, data ~> i1.a, data ~> i1.b}
        i1 = {Foo, nil, c ~> i2.a, d ~> i2.b}
        i2 = {Foo, nil}
      end

    assert t == %WF{map: %{
             _: {SrcAlias, nil, [data: [{:i1, :a}, {:i1, :b}]]},
             i1: {Foo, nil, [c: [{:i2, :a}], d: [{:i2, :b}]]},
             i2: {Foo, nil, []}
           }}
  end

  test "if underscores are transformed correctly" do
    t1 =
      workflow do
        _ = {Source, _, data ~> i.a, data ~> i.b}
        i = {Foo, _}
      end

    t2 =
      workflow do
        _ = {Source, _, data ~> i.a, data ~> i.b}
        i = {Foo, nil}
      end

    assert t1 == t2
  end

  test "if both uses of source are valid" do
    t1 =
      workflow do
        _ = {Source, _}
      end

    t2 =
      workflow do
        _ = {Skitter.Workflow.Source, _}
      end

    assert t1 == t2
  end

  # Error Reporting
  # ---------------

  test "if incorrect syntax is reported" do
    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      workflow(do: {Source, nil})
    end
  end

  test "if duplicate names are reported" do
    assert_definition_error ~r/Duplicate component instance name: .*/ do
      workflow do
        i = {NoPorts, nil}
        i = {NoPorts, nil}
      end
    end
  end

  test "if links to unknown names are reported" do
    assert_definition_error ~r/Unknown component instance name: .*/ do
      workflow do
        _ = {Source, nil, data ~> i.a, data ~> i.b}
        i = {Foo, nil, c ~> does_not_exist.a}
      end
    end
  end

  test "if links to wrong in ports are reported" do
    assert_definition_error ~r/`.*` is not a valid in port of `.*`/ do
      workflow do
        _ =
          {Source, nil, data ~> i1.a, data ~> i1.b, data ~> i2.a, data ~> i2.b}

        i1 = {Foo, nil, d ~> i2.does_not_exist}
        i2 = {Foo, nil}
      end
    end
  end

  test "if links to wrong out ports are reported" do
    assert_definition_error ~r/`.*` is not a valid out port of `.*`/ do
      workflow do
        _ =
          {Source, nil, data ~> i1.a, data ~> i1.b, data ~> i2.a, data ~> i2.b}

        i1 = {Foo, nil, does_not_exist ~> i2.a}
        i2 = {Foo, nil}
      end
    end
  end

  test "if incorrect components are reported" do
    assert_definition_error ~r/`.*` does not exist or is not loaded/ do
      workflow do
        _ = {Source, nil}
        i = {DoesNotExist, nil}
      end
    end

    assert_definition_error ~r/`.*` is not a valid skitter component/ do
      workflow do
        _ = {Source, nil}
        i = {Enum, nil}
      end
    end
  end

  test "if unconnected in ports are reported" do
    assert_definition_error "Unused in ports present in workflow" do
      workflow do
        _ = {Source, _, data ~> i.a}
        i = {Foo, _}
      end
    end
  end

  test "if a missing source is reported" do
    assert_definition_error ~r/Each workflow must contain a `Source` with .*/ do
      workflow do
        i = {NoPorts, nil}
      end
    end
  end

  test "if an incorrect source is reported" do
    assert_definition_error ~r/`.*` is not a valid workflow source/ do
      workflow do
        _ = {Foo, _}
      end
    end
  end
end
