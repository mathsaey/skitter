# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule WorkflowTest do
  use ExUnit.Case

  import Skitter.Workflow
  import Skitter.Component

  component Identity, in: value, out: value do
    react value do
      value ~> value
    end
  end

  def example_workflow do
    workflow do
      source s ~> i.value
      i = {Identity, _}
    end
  end

  doctest Skitter.Workflow
end
