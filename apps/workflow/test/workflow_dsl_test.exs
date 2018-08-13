defmodule Skitter.WorkflowDSLTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  import Skitter.Workflow.DSL
  import Skitter.Component

  alias Skitter.Workflow.Source

  # ---------------- #
  # Extra Assertions #
  # ---------------- #

  defmacro assert_definition_error(do: body) do
    quote do
      assert_raise Skitter.Workflow.DefinitionError, fn -> unquote(body) end
    end
  end

  defmacro assert_warning(do: body) do
    quote do
      capture = capture_io(:stderr, fn -> unquote(body) end)
      assert String.contains?(capture, "warning")
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

    assert t1 == [{0, NoPorts, nil, []}]
    assert t2 == [{0, NoPorts, nil, []}, {1, NoPorts, nil, []}]
  end

  test "if both triple and double element tuples are handled correctly" do
    t =
      workflow do
        double = {Foo, nil}
        triple = {Source, nil, data ~> double.a, data ~> double.b}
      end

    assert t == [
             {0, Foo, nil, []},
             {1, Source, nil, [data: [{0, :a}, {0, :b}]]}
           ]
  end

  test "if links and names are parsed correctly" do
    t =
      workflow do
        i1 = {Source, nil, data ~> i2.a, data ~> i2.b}
        i2 = {Foo, nil, c ~> i3.a, d ~> i3.b}
        i3 = {Foo, nil}
      end

    assert t == [
             {0, Source, nil, [data: [{1, :a}, {1, :b}]]},
             {1, Foo, nil, [c: [{2, :a}], d: [{2, :b}]]},
             {2, Foo, nil, []}
           ]
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
    assert_definition_error do
      workflow(do: {Foo, nil})
    end
  end

  test "if duplicate names are reported" do
    assert_definition_error do
      workflow do
        i = {NoPorts, nil}
        i = {NoPorts, nil}
      end
    end
  end

  test "if links to unknown names are reported" do
    assert_definition_error do
      workflow do
        i = {Foo, nil, c ~> does_not_exist.a}
      end
    end
  end

  test "if links to wrong in ports are reported" do
    assert_definition_error do
      workflow do
        i1 = {Foo, nil, d ~> i2.does_not_exist}
        i2 = {Foo, nil}
      end
    end
  end

  test "if links to wrong out ports are reported" do
    assert_definition_error do
      workflow do
        i1 = {Foo, nil, does_not_exist ~> i2.a}
        i2 = {Foo, nil}
      end
    end
  end

  test "if incorrect components are reported" do
    assert_definition_error do
      workflow do
        i = {DoesNotExist, nil}
      end
    end

    assert_definition_error do
      workflow do
        i = {Enum, nil}
      end
    end
  end

  test "if warnings are produced when in ports are not connected" do
    assert_warning do
      workflow do
        _ = {Source, _, data ~> i.a}
        i = {Foo, _}
      end
    end
  end
end
