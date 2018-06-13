defmodule Skitter.WorkflowDSLTest do
  use ExUnit.Case, async: true

  import Skitter.Workflow.DSL
  import Skitter.Component

  # ---------------- #
  # Extra Assertions #
  # ---------------- #

  defmacro assert_definition_error(do: body) do
    quote do
      assert_raise Skitter.Workflow.DefinitionError, fn -> unquote(body) end
    end
  end

  # -------------- #
  # Test Component #
  # -------------- #

  component Foo, in: [a, b, c], out: [d, e, f] do
    react _a, _b, _c do
    end
  end

  # ----- #
  # Tests #
  # ----- #

  doctest Skitter.Workflow.DSL

  test "if blocks and single statements are handled correctly" do
    t1 = workflow(do: i1 = {Foo, nil})

    t2 =
      workflow do
        i1 = {Foo, nil}
        i2 = {Foo, nil}
      end

    assert t1 == [{0, Foo, nil, []}]
    assert t2 == [{0, Foo, nil, []}, {1, Foo, nil, []}]
  end

  test "if both triple and double element tuples are handled correctly" do
    t =
      workflow do
        double = {Foo, nil}
        triple = {Foo, nil, e ~> double.a}
      end

    assert t == [{0, Foo, nil, []}, {1, Foo, nil, [e: [{0, :a}]]}]
  end

  test "if links and names are parsed correctly" do
    t =
      workflow do
        i1 = {Foo, nil, d ~> i2.a, d ~> i2.b, e ~> i2.c}
        i2 = {Foo, nil}
      end

    assert t == [
             {0, Foo, nil, [d: [{1, :a}, {1, :b}], e: [{1, :c}]]},
             {1, Foo, nil, []}
           ]
  end

  test "if underscores are transformed correctly" do
    t1 = workflow(do: i = {Foo, _})
    t2 = workflow(do: i = {Foo, nil})

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
        i = {Foo, nil}
        i = {Foo, nil}
      end
    end
  end

  test "if links to unknown names are reported" do
    assert_definition_error do
      workflow do
        i = {Foo, nil, d ~> does_not_exist.a}
      end
    end
  end

  test "if links to wrong ports are reported" do
    assert_definition_error do
      workflow do
        i1 = {Foo, nil, d ~> i2.does_not_exist}
        i2 = {Foo, nil}
      end
    end
  end

  test "if incorrect componets are reported" do
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
end
