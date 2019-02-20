# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.WorkflowDSLTest do
  use ExUnit.Case, async: true

  import Skitter.Component
  import Skitter.Workflow.DSL
  import Skitter.Test.Assertions

  # -------------- #
  # Test Component #
  # -------------- #

  component Id, in: val, out: val do
    react v do
      v ~> val
    end
  end

  # ----- #
  # Tests #
  # ----- #

  test "metadata generation" do
    defmodule Metadata do
      workflow W, in: [a, b, c] do
      end
    end

    assert Metadata.W.__skitter_metadata__() == %Skitter.Workflow.Metadata{
             name: "W",
             description: "",
             in_ports: [:a, :b, :c]
           }
  end

  test "source link parsing" do
    defmodule SourceLinks do
      workflow W, in: [a, b] do
        a ~> x.val
        b ~> y.val
        b ~> z.val

        x = instance Id
        y = instance Id
        z = instance Id
      end
    end

    assert SourceLinks.W.__skitter_links__() == %{
             :a => [x: :val],
             :b => [y: :val, z: :val]
           }
  end

  test "instance link parsing" do
    defmodule InstanceLinks do
      workflow W, in: a do
        x = instance Id
        y = instance Id
        z = instance Id

        a ~> x.val
        x.val ~> y.val
        x.val ~> z.val
      end
    end

    assert InstanceLinks.W.__skitter_links__() == %{
             :a => [x: :val],
             {:x, :val} => [y: :val, z: :val]
           }
  end

  test "instance parsing" do
    defmodule Instances do
      workflow W, in: a do
        a ~> x.val
        a ~> y.val

        x = instance Id
        y = instance Id, :foo
      end
    end

    assert Instances.W.__skitter_instances__() == %{
             x: {Id, nil},
             y: {Id, :foo}
           }
  end

  # Error Reporting
  # ---------------

  test "if incorrect syntax is reported" do
    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      defmodule Error do
        workflow W, in: s do
          source a
        end
      end
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      defmodule Error do
        workflow W, in: s do
          i = Id
        end
      end
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      defmodule Error do
        workflow W, in: s do
          :i = instance Id
        end
      end
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      defmodule Error do
        workflow W, in: s do
          i = instance Id
          s ~> i
        end
      end
    end

    assert_definition_error ~r/Invalid workflow syntax: .*/ do
      defmodule Error do
        workflow W, in: s do
          i = instance Id, 5, :foo
        end
      end
    end
  end

  test "if duplicate names are reported" do
    assert_definition_error ~r/Duplicate identifier in workflow: .*/ do
      defmodule Error do
        workflow W, in: s do
          s ~> i.val

          i = instance Id
          i = instance Id
        end
      end
    end

    assert_definition_error ~r/Duplicate identifier in workflow: .*/ do
      defmodule Error do
        workflow W, in: s do
          s ~> s.val
          s = instance Id
        end
      end
    end
  end

  test "if missing modules are reported" do
    assert_definition_error ~r/`.*` does not exist or is not loaded/ do
      workflow Error, in: s do
        s ~> i.val
        i = instance DoesNotExist
      end
    end
  end

  test "if existing modules which are not a component are reported" do
    assert_definition_error ~r/`.*` is not a skitter component/ do
      workflow Error, in: s do
        s ~> i.val
        i = instance Enum
      end
    end
  end

  test "if links from wrong out ports are reported" do
    assert_definition_error ~r/`.*` is not a valid out port of `.*`/ do
      defmodule Error do
        workflow W, in: s do
          i1 = instance Id
          i2 = instance Id

          s ~> i1.val
          i1.x ~> i2.val
        end
      end
    end
  end

  test "if links to unknown names are reported" do
    assert_definition_error ~r/Unknown identifier: .*/ do
      defmodule Error do
        workflow W, in: s do
          s ~> i.val
        end
      end
    end
    assert_definition_error ~r/Unknown identifier: .*/ do
      defmodule Error do
        workflow W, in: s do
          i = instance Id
          x ~> i.val
        end
      end
    end
  end

  test "if unconnected in ports are reported" do
    assert_definition_error ~r/Unused in ports present in workflow: `.*`/ do
      defmodule Error do
        workflow W, in: s do
          i1 = instance Id
        end
      end
    end
  end

  test "if links to wrong in ports are reported" do
    assert_definition_error ~r/`.*` is not a valid in port of `.*`/ do
      defmodule Error do
        workflow W, in: s do
          i1 = instance Id
          s ~> i1.nope
        end
      end
    end
  end
end
