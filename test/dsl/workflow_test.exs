# Copyright 2018 - 2021 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.WorkflowTest do
  use ExUnit.Case, async: true

  import Skitter.DSL.Workflow
  import Skitter.DSL.Component, only: [defcomponent: 3]

  defcomponent Example, in: in_port, out: out_port, strategy: Dummy do
  end

  defcomponent Join, in: [left, right], out: _, strategy: Dummy do
  end

  doctest Skitter.DSL.Workflow
end
