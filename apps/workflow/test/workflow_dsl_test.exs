defmodule Skitter.WorkflowDSLTest do
  use ExUnit.Case, async: true

  import Skitter.Workflow.DSL
  import Skitter.Component

  alias Skitter.Workflow.Source

  # ---------------- #
  # Extra Assertions #
  # ---------------- #

  defmacro assert_definition_error(
             msg \\ quote do
               ~r/.*/
             end,
             do: body
           ) do
    quote do
      assert_raise Skitter.Workflow.DefinitionError, unquote(msg), fn ->
        unquote(body)
      end
    end
  end

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

  doctest Skitter.Workflow.DSL

  test "if blocks and single statements are handled correctly" do
    t1 = workflow(do: i1 = {NoPorts, nil})

    t2 =
      workflow do
        i1 = {NoPorts, nil}
        i2 = {NoPorts, nil}
      end

    assert t1 == %{i1: {NoPorts, nil, []}}
    assert t2 == %{i1: {NoPorts, nil, []}, i2: {NoPorts, nil, []}}
  end

  test "if both triple and double element tuples are handled correctly" do
    t =
      workflow do
        double = {Foo, nil}
        triple = {Source, nil, data ~> double.a, data ~> double.b}
      end

    assert t == %{
             double: {Foo, nil, []},
             triple: {Source, nil, [data: [{:double, :a}, {:double, :b}]]}
           }
  end

  test "if links and names are parsed correctly" do
    t =
      workflow do
        i1 = {Source, nil, data ~> i2.a, data ~> i2.b}
        i2 = {Foo, nil, c ~> i3.a, d ~> i3.b}
        i3 = {Foo, nil}
      end

    assert t == %{
             i1: {Source, nil, [data: [{:i2, :a}, {:i2, :b}]]},
             i2: {Foo, nil, [c: [{:i3, :a}], d: [{:i3, :b}]]},
             i3: {Foo, nil, []}
           }
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
end
