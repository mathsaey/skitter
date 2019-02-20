# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule WorkflowTest do
  use ExUnit.Case

  import Skitter.Workflow
  require Skitter.Component

  Skitter.Component.component Identity, in: value, out: value do
    react value do
      value ~> value
    end
  end

  defmodule Example do
    workflow Workflow, in: [s1, s2] do
      s1 ~> i1.value
      s2 ~> i2.value
      i2.value ~> i3.value

      i1 = instance Identity
      i2 = instance Identity
      i3 = instance Identity
    end
  end

  doctest Skitter.Workflow
end
