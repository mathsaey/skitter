# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.WorkflowTest do
  use ExUnit.Case, async: true

  alias Skitter.Workflow
  alias Skitter.Workflow.Node

  import Skitter.Workflow
  import Skitter.DSL.Component

  doctest Skitter.Workflow
end
